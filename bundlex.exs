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
        os_deps: [
          ffmpeg: [
            {:precompiled, Membrane.PrecompiledDependencyProvider.get_dependency_url(:ffmpeg),
            ["libswresample", "libavutil"]},
            {:pkg_config, ["libswresample", "libavutil"]}
          ],
        ],
        preprocessor: Unifex
      ]
    ]
  end
end
