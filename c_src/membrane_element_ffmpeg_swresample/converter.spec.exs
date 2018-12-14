module Membrane.Element.FFmpeg.SWResample.Converter.Native

# Function creating native handler of converter.
#
# Expects sample format (encoded as integer, using
# `Membrane.Caps.Audio.Raw.Format.serialize/1`), sample rate and number of channels
# for input and output data, respectively.
#
# Currently supported formats are u8, s16le, s32le, f32le, f64le and s24le (input only)
spec create(
       input_format :: unsigned,
       input_rate :: int,
       input_channels :: int,
       src_format :: unsigned,
       src_rate :: int,
       src_channels :: int
     ) :: {:ok :: label, state} | {:error :: label, reason :: atom}

# Function that converts data according to a native handle.
#
# Expects the native handle, created with create/6 and binary data to convert.
#
# Returns converted samples.
#
# When converter is doing sample rate conversion, which requires "future" samples,
# samples will be buffered internally. In order to flush them,
# invoke `convert/2` with an empty binary.
#
# WARNING: Converter won't flush anything until it has enough samples for conversion to happen,
# so you won't be able to resample only a couple of samples. The actual threshold depends on
# conversion parameters.
spec convert(payload, state) :: {:ok :: label, payload} | {:error :: label, reason :: atom}

dirty :cpu, [convert: 2]
