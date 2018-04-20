#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>

typedef struct ConverterHandle {
  struct SwrContext* swr_ctx;
  enum AVSampleFormat src_sample_fmt, dst_sample_fmt;
  int src_rate, dst_rate;
  int src_nb_channels, dst_nb_channels;
  char from_s24le;
} ConverterHandle;


extern char* init(
  ConverterHandle* handle,
  char from_s24le,
  enum AVSampleFormat src_sample_fmt, int src_rate, int64_t src_ch_layout,
  enum AVSampleFormat dst_sample_fmt, int dst_rate, int64_t dst_ch_layout
);

extern char* convert(
  ConverterHandle* handle,
  uint8_t* input, int input_size,
  uint8_t** output, int* output_size
);

extern char* flush(
  ConverterHandle* handle,
  uint8_t** output, int* output_size
);
