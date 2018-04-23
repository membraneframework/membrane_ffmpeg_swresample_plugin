defmodule Membrane.Element.FFmpeg.SWResample.BundlexProject do
  use Bundlex.Project

  def project do
    [
      nif: nif(Bundlex.platform())
    ]
  end

  defp nif(platform) do
    [
      membrane_element_ffmpeg_swresample_converter: [
        sources: ["converter.c", "converter_lib.c"],
        deps: [membrane_common_c: :membrane],
        libs: libs(platform)
      ]
    ]
  end

  defp libs(platform) do
    case platform do
      :windows32 ->
        [
          "ext/windows/32/avutil.lib",
          "ext/windows/32/swresample.lib"
        ]

      :windows64 ->
        [
          "ext/windows/64/avutil.lib",
          "ext/windows/64/swresample.lib"
        ]

      _ ->
        ["avutil", "swresample"]
    end
  end
end
