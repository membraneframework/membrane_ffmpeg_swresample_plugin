defmodule Membrane.FFmpeg.SWResample.BundlexProject do
  use Bundlex.Project

  def project do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      converter: [
        interface: :nif,
        sources: ["converter.c", "converter_lib.c"],
        deps: [membrane_common_c: :membrane, unifex: :unifex],
        pkg_configs: ["libavutil", "libswresample"],
        preprocessor: Unifex
      ]
    ]
  end
end
