defmodule Membrane.FFmpeg.SWResample.BundlexProject do
  use Bundlex.Project

  defp get_ffmpeg() do
    case Bundlex.get_target() do
      %{os: "linux"} ->
        {:precompiled,
         "https://github.com/membraneframework-precompiled/precompiled_ffmpeg/releases/download/latest/ffmpeg_linux.tar.gz"}

      %{architecture: "x86_64", os: "darwin" <> _rest_of_os_name} ->
        {:precompiled,
         "https://github.com/membraneframework-precompiled/precompiled_ffmpeg/releases/download/latest/ffmpeg_macos_intel.tar.gz"}

      %{architecture: "aarch64", os: "darwin" <> _rest_of_os_name} ->
        {:precompiled,
         "https://github.com/membraneframework-precompiled/precompiled_ffmpeg/releases/download/latest/ffmpeg_macos_arm.tar.gz"}

      _other ->
        nil
    end
  end

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
        os_deps: [{[get_ffmpeg(), :pkg_config], ["libswresample"]}],
        preprocessor: Unifex
      ]
    ]
  end
end
