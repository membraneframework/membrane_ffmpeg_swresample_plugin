#include "converter.h"

#define MEMBRANE_LOG_TAG "Membrane.Element.FFmpeg.SWResample.Converter.Native"

static int membrane_sample_fmt_to_av_sample_fmt(int in, char dir, char* s24le, enum AVSampleFormat* out);
static int nb_channels_to_av_layout(int channels, int64_t* av_layout);

UNIFEX_TERM create(UnifexEnv* env, unsigned int src_format, int src_rate, int src_channels, unsigned int dst_format, int dst_rate, int dst_channels) {
  enum AVSampleFormat src_av_format, dst_av_format;
  int ret_val;
  char from_s24le;
  ret_val = membrane_sample_fmt_to_av_sample_fmt(src_format, 0, &from_s24le, &src_av_format);
  if(ret_val) return membrane_util_make_error_args(env, "src_format", "Unsupported sample format");
  ret_val = membrane_sample_fmt_to_av_sample_fmt(dst_format, 1, NULL, &dst_av_format);
  if(ret_val) return  membrane_util_make_error_args(env, "dst_format", "Unsupported sample format");
  int64_t src_layout, dst_layout;
  ret_val = nb_channels_to_av_layout(src_channels, &src_layout);
  if(ret_val) return membrane_util_make_error_args(env, "src_channels", "Unsupported number of channels");
  ret_val = nb_channels_to_av_layout(dst_channels, &dst_layout);
  if(ret_val) return membrane_util_make_error_args(env, "dst_channels", "Unsupported number of channels");

  ConverterState* state = unifex_alloc_state(env);
  char* init_error = lib_init(
    state,
    from_s24le,
    src_av_format, src_rate, src_layout,
    dst_av_format, dst_rate, dst_layout
  );
  if(init_error) {
    return membrane_util_make_error_internal(env, init_error);
  }

  UNIFEX_TERM res = create_result_ok(env, state);
  unifex_release_state(env, state);
  return res;
}

UNIFEX_TERM convert(UnifexEnv* env, UnifexPayload* in_payload, ConverterState* state) {
  uint8_t* output;
  int output_size;
  char* conversion_error;
  if(in_payload->size > 0) {
    conversion_error = lib_convert(state, (uint8_t*) in_payload->data, in_payload->size, &output, &output_size);
  } else {
    conversion_error = lib_flush(state, &output, &output_size);
  }
  if(conversion_error) {
    return membrane_util_make_error_internal(env, conversion_error);
  }
  UnifexPayload* out_payload = unifex_payload_alloc(env, in_payload->type, output_size);
  memcpy(out_payload->data, output, output_size);
  av_freep(&output);

  return convert_result_ok(env, out_payload);
}

void handle_destroy_state(UnifexEnv* env, ConverterState* state) {
  UNIFEX_UNUSED(env);
  if(state) {
    swr_free(&(state->swr_ctx));
  }
}

static int membrane_sample_fmt_to_av_sample_fmt(int in, char dir, char* s24le, enum AVSampleFormat* out) {
  int ret_val = 0;
  if(s24le) *s24le = 0;
  switch (in) {
    case MEMBRANE_SAMPLE_FORMAT_TYPE_U | 8:   *out = AV_SAMPLE_FMT_U8; break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_S | 16:  *out = AV_SAMPLE_FMT_S16; break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_S | 24:
      if(dir == 1)
        ret_val = -1;
      else {
        *out = AV_SAMPLE_FMT_S32;
        if(s24le) *s24le = 1;
      }
      break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_S | 32:  *out = AV_SAMPLE_FMT_S32; break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_F | 32:  *out = AV_SAMPLE_FMT_FLT; break;
    case MEMBRANE_SAMPLE_FORMAT_TYPE_F | 64:  *out = AV_SAMPLE_FMT_DBL; break;
    default:
      ret_val = -1;
  }
  return ret_val;
}

static int nb_channels_to_av_layout(int channels, int64_t* av_layout) {
  int ret_val = 0;
  switch (channels) {
    case 1: *av_layout = AV_CH_LAYOUT_MONO; break;
    case 2: *av_layout = AV_CH_LAYOUT_STEREO; break;
    default:
      ret_val = -1;
  }
  return ret_val;
}
