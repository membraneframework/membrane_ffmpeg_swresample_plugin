defmodule Membrane.Element.FFmpeg.SWResample.ConverterNative do
  require Bundlex.Loader

  @on_load :load_nifs

  @doc false
  def load_nifs do
    Bundlex.Loader.load_lib_nif!(:membrane_element_ffmpeg_swresample, :membrane_element_ffmpeg_swresample_converter)
  end


  @spec create(integer, integer, integer, integer, integer, integer) ::
  {:ok, any}
  def create(_sink_format, _sink_rate, _sink_channels, _src_format, _src_rate, _src_channels), do: raise "NIF fail"


  @spec convert(any, binary) ::
  {:ok, binary} | {:error, any}
  def convert(_native, _data), do: raise "NIF fail"

end
