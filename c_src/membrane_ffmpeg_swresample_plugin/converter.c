#include "converter.h"

#define MEMBRANE_LOG_TAG UNIFEX_MODULE

static int membrane_sample_fmt_to_av_sample_fmt(int in, char dir, char *s24le,
                                                enum AVSampleFormat *out);
static int nb_channels_to_av_layout(int channels, int64_t *av_layout);

UNIFEX_TERM create(UnifexEnv *env, unsigned int src_format, int src_rate,
                   int src_channels, unsigned int dst_format, int dst_rate,
                   int dst_channels) {
  UNIFEX_TERM result;
  enum AVSampleFormat src_av_format, dst_av_format;
  char *err_reason;
  char from_s24le;
  ConverterState *state = NULL;

  if (membrane_sample_fmt_to_av_sample_fmt(src_format, 0, &from_s24le,
                                           &src_av_format)) {
    err_reason = "unsupported_src_format";
    goto create_exit;
  }
  if (membrane_sample_fmt_to_av_sample_fmt(dst_format, 1, NULL,
                                           &dst_av_format)) {
    err_reason = "unsupported_dst_format";
    goto create_exit;
  }
  int64_t src_layout, dst_layout;
  if (nb_channels_to_av_layout(src_channels, &src_layout)) {
    err_reason = "unsupported_src_channels_no";
    goto create_exit;
  }
  if (nb_channels_to_av_layout(dst_channels, &dst_layout)) {
    err_reason = "unsupported_dst_channels_no";
    goto create_exit;
  }

  state = unifex_alloc_state(env);
  err_reason = lib_init(state, from_s24le, src_av_format, src_rate, src_layout,
                        dst_av_format, dst_rate, dst_layout);
  if (err_reason) {
    goto create_exit;
  }

create_exit:
  if (err_reason) {
    result = create_result_error(env, err_reason);
  } else {
    result = create_result_ok(env, state);
  }
  if (state) {
    unifex_release_state(env, state);
  }
  return result;
}

UNIFEX_TERM convert(UnifexEnv *env, UnifexPayload *in_payload,
                    ConverterState *state) {
  uint8_t *output;
  int output_size;
  char *conversion_error;
  if (in_payload->size > 0) {
    conversion_error = lib_convert(state, (uint8_t *)in_payload->data,
                                   in_payload->size, &output, &output_size);
  } else {
    conversion_error = lib_flush(state, &output, &output_size);
  }
  if (conversion_error) {
    return convert_result_error(env, conversion_error);
  }
  UnifexPayload out_payload;
  unifex_payload_alloc(env, in_payload->type, output_size, &out_payload);
  memcpy(out_payload.data, output, output_size);
  lib_free_output(&output);

  UNIFEX_TERM res = convert_result_ok(env, &out_payload);
  unifex_payload_release(&out_payload);
  return res;
}

void handle_destroy_state(UnifexEnv *env, ConverterState *state) {
  UNIFEX_UNUSED(env);
  if (state) {
    lib_destroy(state);
  }
}

static int membrane_sample_fmt_to_av_sample_fmt(int in, char dir, char *s24le,
                                                enum AVSampleFormat *out) {
  int error = 0;
  if (s24le)
    *s24le = 0;
  switch (in) {
  case MEMBRANE_SAMPLE_FORMAT_TYPE_U | 8:
    *out = AV_SAMPLE_FMT_U8;
    break;
  case MEMBRANE_SAMPLE_FORMAT_TYPE_S | 16:
    *out = AV_SAMPLE_FMT_S16;
    break;
  case MEMBRANE_SAMPLE_FORMAT_TYPE_S | 24:
    if (dir == 1)
      error = -1;
    else {
      *out = AV_SAMPLE_FMT_S32;
      if (s24le)
        *s24le = 1;
    }
    break;
  case MEMBRANE_SAMPLE_FORMAT_TYPE_S | 32:
    *out = AV_SAMPLE_FMT_S32;
    break;
  case MEMBRANE_SAMPLE_FORMAT_TYPE_F | 32:
    *out = AV_SAMPLE_FMT_FLT;
    break;
  case MEMBRANE_SAMPLE_FORMAT_TYPE_F | 64:
    *out = AV_SAMPLE_FMT_DBL;
    break;
  default:
    error = -1;
  }
  return error;
}

static int nb_channels_to_av_layout(int channels, int64_t *av_layout) {
  int error = 0;
  switch (channels) {
  case 1:
    *av_layout = AV_CH_LAYOUT_MONO;
    break;
  case 2:
    *av_layout = AV_CH_LAYOUT_STEREO;
    break;
  default:
    error = -1;
  }
  return error;
}
