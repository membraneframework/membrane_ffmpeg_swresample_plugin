defmodule Membrane.Element.FFmpeg.SWResample.Converter.Native do
  @moduledoc """
  This module provides wrappers for NIFs utilizing C SWResample library
  """
  require Bundlex.Loader

  @on_load :load_nifs

  @doc false
  def load_nifs do
    Bundlex.Loader.load_lib_nif!(
      :membrane_element_ffmpeg_swresample,
      :membrane_element_ffmpeg_swresample_converter
    )
  end

  @opaque handle_t :: reference()

  @doc """
  Function creating native handler of converter.

  Expects sample format (encoded as integer, using
  `Membrane.Caps.Audio.Raw.Format.serialize/1`), sample rate and number of channels
  for input and output data, respectively.

  Currently supported formats are u8, s16le, s32le, f32le, f64le and s24le (input only)

  Returns {:ok, native_handle} or {:error, reason}.
  """
  @spec create(integer, integer, integer, integer, integer, integer) ::
          {:ok, handle_t} | {:error, any}
  def create(_sink_format, _sink_rate, _sink_channels, _src_format, _src_rate, _src_channels),
    do: raise("NIF fail")

  @doc """
  Function that converts data according to a native handle.

  Expects the native handle, created with create/6 and binary data to convert.

  Returns converted data.

  Note: Not all samples are guaranteed to be converted. Some of them may be stored
  in handle to be converted when long enough chunk is collected.
  """
  @spec convert(handle_t, binary) :: {:ok, binary} | {:error, any}
  def convert(_native, _data), do: raise("NIF fail")
end
