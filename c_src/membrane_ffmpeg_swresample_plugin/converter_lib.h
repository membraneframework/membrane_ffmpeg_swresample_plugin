#include <libswresample/swresample.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <unifex/unifex.h>

typedef struct ConverterState
{
  struct SwrContext *swr_ctx;
  enum AVSampleFormat src_sample_fmt, dst_sample_fmt;
  int src_rate, dst_rate;
  int src_nb_channels, dst_nb_channels;
  char from_s24le;
} ConverterState;

char *lib_init(ConverterState *state, char from_s24le,
               enum AVSampleFormat src_sample_fmt, int src_rate,
               const AVChannelLayout *src_ch_layout,
               enum AVSampleFormat dst_sample_fmt, int dst_rate,
               const AVChannelLayout *dst_ch_layout);

char *lib_convert(ConverterState *state, uint8_t *input, int input_size,
                  uint8_t **output, int *output_size);

char *lib_flush(ConverterState *state, uint8_t **output, int *output_size);

void lib_free_output(uint8_t **output);

void lib_destroy(ConverterState *state);
