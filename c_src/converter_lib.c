#include "converter_lib.h"


char* init(
  ConverterHandle* handle,
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

  *handle = (ConverterHandle) {
    .swr_ctx = swr_ctx,
    .src_rate = src_rate,
    .dst_rate = dst_rate,
    .src_sample_fmt = src_sample_fmt,
    .dst_sample_fmt = dst_sample_fmt,
    .src_nb_channels = av_get_channel_layout_nb_channels(src_ch_layout),
    .dst_nb_channels = av_get_channel_layout_nb_channels(dst_ch_layout),
  };

  return NULL;
}

static char* handle_conversion_error(char* error, uint8_t** src_data, uint8_t** dst_data) {
  if (src_data)
    av_freep(&src_data[0]);
  av_freep(&src_data);
  if (dst_data)
    av_freep(&dst_data[0]);
  av_freep(&dst_data);
  return error;
}

char* convert(ConverterHandle* handle, uint8_t* input, int input_size, uint8_t** output, int* output_size) {
  uint8_t **src_data = NULL, **dst_data = NULL;
  int src_linesize, dst_linesize;
  int src_nb_samples = input_size / handle->src_nb_channels / av_get_bytes_per_sample(handle->src_sample_fmt);


  if(0 > av_samples_alloc_array_and_samples(
      &src_data,
      &src_linesize,
      handle->src_nb_channels,
      src_nb_samples,
      handle->src_sample_fmt,
      0
    ))
      return handle_conversion_error("Could not allocate source samples", src_data, dst_data);

  memcpy(src_data[0], input, av_samples_get_buffer_size(
    &src_linesize,
    handle->src_nb_channels,
    src_nb_samples,
    handle->src_sample_fmt,
    1
  ));

  int max_dst_nb_samples = av_rescale_rnd(
    swr_get_delay(handle-> swr_ctx, handle->src_rate) + src_nb_samples,
    handle->dst_rate,
    handle->src_rate,
    AV_ROUND_UP
  );

  if (0 > av_samples_alloc_array_and_samples(
    &dst_data,
    &dst_linesize,
    handle->dst_nb_channels,
    max_dst_nb_samples,
    handle->dst_sample_fmt,
    0))
      return handle_conversion_error("Could not allocate destination samples", src_data, dst_data);

  int dst_nb_samples = swr_convert(
    handle->swr_ctx,
    dst_data,
    max_dst_nb_samples,
    (const uint8_t **)src_data,
    src_nb_samples
  );
  if (dst_nb_samples < 0)
    return handle_conversion_error("Error while converting", src_data, dst_data);

  if (dst_nb_samples == 0) {
    *output_size = 0;
  } else {
    *output_size = av_samples_get_buffer_size(
      &dst_linesize,
      handle->dst_nb_channels,
      dst_nb_samples,
      handle->dst_sample_fmt,
      1
    );
    if(*output_size < 0)
      return handle_conversion_error("Error calculating output size", src_data, dst_data);
  }

  *output = dst_data[0];
  av_freep(&dst_data);
  av_freep(&src_data[0]);
  av_freep(&src_data);

  return NULL;
}
