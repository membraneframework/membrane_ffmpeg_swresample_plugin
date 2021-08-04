defmodule Membrane.FFmpeg.SWResample.BundlexProject do
  use Bundlex.Project

  def project do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      converter:
        [
          interface: :nif,
          sources: ["converter.c", "converter_lib.c"],
          deps: [membrane_common_c: :membrane, unifex: :unifex],
          preprocessor: Unifex
        ] ++ platform_specific(Bundlex.platform())
    ]
  end

  defp platform_specific(:windows32) do
    [
      includes: ["ext/include"],
      libs: [
        "ext/windows/32/avutil.lib",
        "ext/windows/32/swresample.lib"
      ]
    ]
  end

  defp platform_specific(:windows64) do
    [
      includes: ["ext/include"],
      libs: [
        "ext/windows/64/avutil.lib",
        "ext/windows/64/swresample.lib"
      ]
    ]
  end

  defp platform_specific(_) do
    [pkg_configs: ["libavutil", "libswresample"]]
  end
end
