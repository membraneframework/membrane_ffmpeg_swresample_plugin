/**
 * Membrane Element: FFmpeg Resampler - Erlang native interface for FFmpeg-based resampler
 *
 * All Rights Reserved, (c) 2017 Mateusz Front
 */
#include "converter.h"

//#define MEMBRANE_LOG_TAG "Membrane.Element.FFmpeg.SWResample.ConverterNative"

#define UNUSED(x) (void)(x)

ErlNifResourceType *RES_CONVERTER_HANDLE_TYPE;

char* init(ConverterHandle* handle) {
  int64_t src_ch_layout = AV_CH_LAYOUT_STEREO, dst_ch_layout = AV_CH_LAYOUT_STEREO;
  int src_rate = 48000, dst_rate = 24000;
  enum AVSampleFormat src_sample_fmt = AV_SAMPLE_FMT_S16, dst_sample_fmt = AV_SAMPLE_FMT_U8;

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

char* handle_conversion_error(char* error, uint8_t** src_data, uint8_t** dst_data) {
  if (src_data)
    av_freep(&src_data[0]);
  av_freep(&src_data);
  if (dst_data)
    av_freep(&dst_data[0]);
  av_freep(&dst_data);
  return error;
}

char* convert(uint8_t* input, int input_size, ConverterHandle* handle, uint8_t** output, int* output_size) {
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


void res_converter_handle_destructor(ErlNifEnv* env, void* value) {
  UNUSED(env);
  ConverterHandle *handle = (ConverterHandle*) value;
  if(handle)
    swr_free(&(handle->swr_ctx));
}

int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  UNUSED(priv_data);
  UNUSED(load_info);
  int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  RES_CONVERTER_HANDLE_TYPE =
    enif_open_resource_type(env, NULL, "ConverterHandle", res_converter_handle_destructor, flags, NULL);
  return 0;
}


static ERL_NIF_TERM export_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  UNUSED(argc);
  UNUSED(argv);
  ConverterHandle *handle = enif_alloc_resource(RES_CONVERTER_HANDLE_TYPE, sizeof(ConverterHandle));

  char* init_error = init(handle);
  if(init_error)
    return membrane_util_make_error_internal(env, init_error);

  ERL_NIF_TERM converter_term = enif_make_resource(env, handle);
  enif_release_resource(handle);

  return membrane_util_make_ok_tuple(env, converter_term);
}


static ERL_NIF_TERM export_convert(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  UNUSED(argc);
  MEMBRANE_UTIL_PARSE_RESOURCE_ARG(0, handle, ConverterHandle, RES_CONVERTER_HANDLE_TYPE);
  MEMBRANE_UTIL_PARSE_BINARY_ARG(1, input);


  ERL_NIF_TERM output_binary_term;
  if(input.size > 0) {
    uint8_t* output;
    int output_size;
    char* conversion_error = convert((uint8_t*) input.data, input.size, handle, &output, &output_size);
    if(conversion_error)
      return membrane_util_make_error_internal(env, conversion_error);

    unsigned char* data_ptr;
    data_ptr = enif_make_new_binary(env, output_size, &output_binary_term);
    memcpy(data_ptr, output, output_size);
    free(output);
  } else {
    enif_make_new_binary(env, 0, &output_binary_term);
  }

  return membrane_util_make_ok_tuple(env, output_binary_term);
}


static ErlNifFunc nif_funcs[] =
{
  {"create", 0, export_create, 0},
  {"convert", 2, export_convert, 0}
};

ERL_NIF_INIT(Elixir.Membrane.Element.FFmpeg.SWResample.ConverterNative, nif_funcs, load, NULL, NULL, NULL);
