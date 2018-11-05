defmodule Membrane.Element.FFmpeg.SWResample.BundlexProject do
  use Bundlex.Project

  def project do
    [
      nifs: [
        converter:
          [
            sources: ["converter.c", "converter_lib.c", "_generated/converter.c"],
            deps: [membrane_common_c: :membrane, unifex: :unifex]
          ] ++ platform_specific(Bundlex.platform())
      ]
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
    [libs: ["avutil", "swresample"]]
  end
end
