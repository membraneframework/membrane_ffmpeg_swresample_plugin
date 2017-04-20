defmodule Membrane.Element.FFmpeg.SWResample.ConverterNative do
  require Bundlex.Loader

  @on_load :load_nifs

  @doc false
  def load_nifs do
    Bundlex.Loader.load_lib_nif!(:membrane_element_ffmpeg_swresample, :membrane_element_ffmpeg_swresample_converter)
  end


  @spec create() ::
  {:ok, any}
  def create(), do: raise "NIF fail"


  @spec convert(any, binary) ::
  {:ok, binary} | {:error, any}
  def convert(_native, _data), do: raise "NIF fail"

end
