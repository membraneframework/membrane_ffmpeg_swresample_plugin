/**
 * Membrane Element: FFmpeg Resampler - Erlang native interface for FFmpeg-based resampler
 *
 * All Rights Reserved, (c) 2017 Mateusz Front
 */
#pragma once

#include <stdio.h>
#include <erl_nif.h>
#include <membrane/membrane.h>

#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>


typedef struct ConverterHandle {
  struct SwrContext* swr_ctx;
  enum AVSampleFormat src_sample_fmt, dst_sample_fmt;
  int src_rate, dst_rate;
  int src_nb_channels, dst_nb_channels;
} ConverterHandle;
