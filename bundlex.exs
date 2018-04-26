defmodule Membrane.Element.FFmpeg.SWResample.BundlexProject do
  use Bundlex.Project

  def project do
    [
      nifs: [
        membrane_element_ffmpeg_swresample_converter: [
          sources: ["converter.c", "converter_lib.c"],
          deps: [membrane_common_c: :membrane],
          includes: ["ext/include"],
          libs: libs(Bundlex.platform())
        ]
      ]
    ]
  end

  defp libs(:windows32) do
    [
      "ext/windows/32/avutil.lib",
      "ext/windows/32/swresample.lib"
    ]
  end

  defp libs(:windows64) do
    [
      "ext/windows/64/avutil.lib",
      "ext/windows/64/swresample.lib"
    ]
  end

  defp libs(_) do
    ["avutil", "swresample"]
  end
end
