/**
 * Membrane Element: FFmpeg Resampler - Erlang native interface for FFmpeg-based resampler
 *
 * All Rights Reserved, (c) 2017 Mateusz Front
 */
#include "converter.h"

//#define MEMBRANE_LOG_TAG "Membrane.Element.FFmpeg.SWResample.ConverterNative"

#define UNUSED(x) (void)(x)

ErlNifResourceType *RES_CONVERTER_HANDLE_TYPE;

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

static char* membrane_sample_fmt_to_av_sample_fmt(int in, enum AVSampleFormat* out) {
  char* err = NULL;
  switch (in) {
    case MEMBRANE_SAMPLE_FORMAT_TYPE_U | 8:   *out = AV_SAMPLE_FMT_U8; break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_S | 16:  *out = AV_SAMPLE_FMT_S16; break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_S | 32:  *out = AV_SAMPLE_FMT_S32; break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_F | 32:  *out = AV_SAMPLE_FMT_FLT; break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_F | 64:  *out = AV_SAMPLE_FMT_DBL; break;
    default:
      asprintf(&err, "Unsupported sample format: %d", in);
  }
  return err;
}

static char* nb_channels_to_av_layout(int channels, int64_t* av_layout) {
  char* err = NULL;
  switch (channels) {
    case 1: *av_layout = AV_CH_LAYOUT_MONO; break;
    case 2: *av_layout = AV_CH_LAYOUT_STEREO; break;
    default:
      asprintf(&err, "Unsupported number of channels: %d", channels);
  }
  return err;
}

static ERL_NIF_TERM export_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  UNUSED(argc);
  MEMBRANE_UTIL_PARSE_UINT_ARG(0, src_format);
  MEMBRANE_UTIL_PARSE_UINT_ARG(1, src_rate);
  MEMBRANE_UTIL_PARSE_UINT_ARG(2, src_channels);
  MEMBRANE_UTIL_PARSE_UINT_ARG(3, dst_format);
  MEMBRANE_UTIL_PARSE_UINT_ARG(4, dst_rate);
  MEMBRANE_UTIL_PARSE_UINT_ARG(5, dst_channels);

  enum AVSampleFormat src_av_format, dst_av_format;
  char* parse_err;
  parse_err = membrane_sample_fmt_to_av_sample_fmt(src_format, &src_av_format);
  if(parse_err) return membrane_util_make_error_internal(env, parse_err);
  parse_err = membrane_sample_fmt_to_av_sample_fmt(dst_format, &dst_av_format);
  if(parse_err) return membrane_util_make_error_internal(env, parse_err);
  int64_t src_layout, dst_layout;
  parse_err = nb_channels_to_av_layout(src_channels, &src_layout);
  if(parse_err) return membrane_util_make_error_internal(env, parse_err);
  parse_err = nb_channels_to_av_layout(dst_channels, &dst_layout);
  if(parse_err) return membrane_util_make_error_internal(env, parse_err);

  ConverterHandle *handle = enif_alloc_resource(RES_CONVERTER_HANDLE_TYPE, sizeof(ConverterHandle));

  char* init_error = init(
    handle,
    src_av_format, src_rate, src_layout,
    dst_av_format, dst_rate, dst_layout
  );
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
    char* conversion_error = convert(handle, (uint8_t*) input.data, input.size, &output, &output_size);
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
  {"create", 6, export_create, 0},
  {"convert", 2, export_convert, 0}
};

ERL_NIF_INIT(Elixir.Membrane.Element.FFmpeg.SWResample.ConverterNative, nif_funcs, load, NULL, NULL, NULL);
