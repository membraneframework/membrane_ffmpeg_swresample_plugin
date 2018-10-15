#include "converter_lib.h"

char* lib_init(
  ConverterState* state,
  char from_s24le,
  enum AVSampleFormat src_sample_fmt, int src_rate, int64_t src_ch_layout,
  enum AVSampleFormat dst_sample_fmt, int dst_rate, int64_t dst_ch_layout
) {

  struct SwrContext* swr_ctx = swr_alloc();
  if (!swr_ctx)
      return "Could not allocate resampler context";


  /* set options */
  av_opt_set_int(swr_ctx, "in_channel_layout",    src_ch_layout, 0);
  av_opt_set_int(swr_ctx, "in_sample_rate",       src_rate, 0);
  av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", src_sample_fmt, 0);
  av_opt_set_int(swr_ctx, "out_channel_layout",    dst_ch_layout, 0);
  av_opt_set_int(swr_ctx, "out_sample_rate",       dst_rate, 0);
  av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", dst_sample_fmt, 0);
  av_opt_set_int(swr_ctx, "dither_method", SWR_DITHER_RECTANGULAR, 0);

  if(swr_init(swr_ctx) < 0)
    return "Failed to initialize the resampling context";

  *state = (ConverterState) {
    .swr_ctx = swr_ctx,
    .src_rate = src_rate,
    .dst_rate = dst_rate,
    .src_sample_fmt = src_sample_fmt,
    .dst_sample_fmt = dst_sample_fmt,
    .src_nb_channels = av_get_channel_layout_nb_channels(src_ch_layout),
    .dst_nb_channels = av_get_channel_layout_nb_channels(dst_ch_layout),
    .from_s24le = from_s24le,
  };

  return NULL;
}

static char* free_conversion_data(char* error, ConverterState* state, uint8_t* input, uint8_t** src_data, uint8_t** dst_data) {
  if(state->from_s24le && input) {
    free(input);
  }

  if (src_data) {
    if(src_data[0]) {
      av_freep(&src_data[0]);
    }
    av_freep(&src_data);
  }

  if (dst_data) {
    if(error && dst_data[0]) {
      av_freep(&dst_data[0]);
    }
    av_freep(&dst_data);
  }

  return error;
}

static char* convert_s24le_to_s32le(uint8_t** data, int* data_size) {
  uint8_t* input = *data;
  int input_size = *data_size;

  if(input_size % 3 != 0) {
    return "Could not convert from s24le to s32le: input size not divisible by 3";
  }

  int output_size = input_size * 4 / 3;
  uint8_t* output = malloc(output_size);

  for(int i = 0; i < input_size / 3; i++){
    uint8_t b0 = input[3 * i];
    uint8_t b1 = input[3 * i + 1];
    uint8_t b2 = input[3 * i + 2];
    output[i * 4] = (b2 << 1) | (b1 >> 7);
    output[i * 4 + 1] = b0;
    output[i * 4 + 2] = b1;
    output[i * 4 + 3] = b2;
  }

  *data = output;
  *data_size = output_size;
  return NULL;
}

char* lib_convert(ConverterState* state, uint8_t* input, int input_size, uint8_t** output, int* output_size) {

  if(state->from_s24le) {
    char* res = convert_s24le_to_s32le(&input, &input_size);
    if(res) {
      return res;
    }
  }

  uint8_t **src_data = NULL, **dst_data = NULL;
  int src_linesize, dst_linesize;
  int src_nb_samples = input_size / state->src_nb_channels / av_get_bytes_per_sample(state->src_sample_fmt);


  if(0 > av_samples_alloc_array_and_samples(
      &src_data,
      &src_linesize,
      state->src_nb_channels,
      src_nb_samples,
      state->src_sample_fmt,
      0
    )) {
      return free_conversion_data("Could not allocate source samples", state, input, src_data, dst_data);
    }

  memcpy(src_data[0], input, av_samples_get_buffer_size(
    &src_linesize,
    state->src_nb_channels,
    src_nb_samples,
    state->src_sample_fmt,
    1
  ));

  int max_dst_nb_samples = av_rescale_rnd(
    swr_get_delay(state-> swr_ctx, state->src_rate) + src_nb_samples,
    state->dst_rate,
    state->src_rate,
    AV_ROUND_UP
  );

  if (0 > av_samples_alloc_array_and_samples(
    &dst_data,
    &dst_linesize,
    state->dst_nb_channels,
    max_dst_nb_samples,
    state->dst_sample_fmt,
    0)) {
      return free_conversion_data("Could not allocate destination samples", state, input, src_data, dst_data);
    }

  int dst_nb_samples = swr_convert(
    state->swr_ctx,
    dst_data,
    max_dst_nb_samples,
    (const uint8_t **)src_data,
    src_nb_samples
  );

  if (dst_nb_samples < 0) {
    return free_conversion_data("Error while converting", state, input, src_data, dst_data);
  }

  if (dst_nb_samples == 0) {
    *output_size = 0;
  } else {
    *output_size = av_samples_get_buffer_size(
      &dst_linesize,
      state->dst_nb_channels,
      dst_nb_samples,
      state->dst_sample_fmt,
      1
    );

    if(*output_size < 0) {
      return free_conversion_data("Error calculating output size", state, input, src_data, dst_data);
    }
  }


  *output = dst_data[0];
  free_conversion_data(NULL, state, input, src_data, dst_data);

  return NULL;
}

char* lib_flush(ConverterState* state, uint8_t** output, int* output_size) {

  uint8_t **dst_data = NULL;
  int dst_linesize;

  int max_dst_nb_samples = av_rescale_rnd(
    swr_get_delay(state-> swr_ctx, state->src_rate),
    state->dst_rate,
    state->src_rate,
    AV_ROUND_UP
  );

  if (max_dst_nb_samples == 0) {
    // nothing was buffered, converter does not need flush
    *output_size = 0;
    *output = NULL;
    return NULL;
  }
  if (0 > av_samples_alloc_array_and_samples(
    &dst_data,
    &dst_linesize,
    state->dst_nb_channels,
    max_dst_nb_samples,
    state->dst_sample_fmt,
    0)) {
      return free_conversion_data("Could not allocate destination samples", state, NULL, NULL, dst_data);
  }

  int dst_nb_samples = swr_convert(
    state->swr_ctx,
    dst_data,
    max_dst_nb_samples,
    NULL,
    0
  );

  if (dst_nb_samples < 0) {
    return free_conversion_data("Error while converting", state, NULL, NULL, dst_data);
  }

  if (dst_nb_samples == 0) {
    *output_size = 0;
  } else {
    *output_size = av_samples_get_buffer_size(
      &dst_linesize,
      state->dst_nb_channels,
      dst_nb_samples,
      state->dst_sample_fmt,
      1
    );
    if(*output_size < 0) {
      return free_conversion_data("Error calculating output size", state, NULL, NULL, dst_data);
    }
  }

  *output = dst_data[0];
  free_conversion_data(NULL, state, NULL, NULL, dst_data);

  return NULL;
}
