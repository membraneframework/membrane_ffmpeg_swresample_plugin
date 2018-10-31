defmodule Membrane.Element.FFmpeg.SWResample.Mixfile do
  use Mix.Project
  Application.put_env(:bundlex, :membrane_element_ffmpeg_swresample, __ENV__)

  @github_url "https://github.com/membraneframework/membrane-element-ffmpeg-swresample"
  @version "0.1.1"

  def project do
    [
      app: :membrane_element_ffmpeg_swresample,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Membrane Multimedia Framework (FFmpeg SWResample Element)",
      package: package(),
      name: "Membrane Element: FFmpeg SWResample",
      output_url: @github_url,
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [],
      mod: {Membrane.Element.FFmpeg.SWResample, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      },
      files: [
        "lib",
        "c_src",
        "ext",
        "mix.exs",
        "README*",
        "LICENSE*",
        ".formatter.exs",
        "bundlex.exs"
      ]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      # {:membrane_core, "~> 0.1"},
      {:membrane_core, github: "membraneframework/membrane-core"},
      {:membrane_caps_audio_raw, github: "membraneframework/membrane-caps-audio-raw"},
      {:bunch, github: "membraneframework/bunch", override: true},
      {:unifex, github: "membraneframework/unifex"},
      {:membrane_common_c, github: "membraneframework/membrane-common-c"},
      {:bundlex, "~> 0.1"},
      {:mockery, "~> 2.1", runtime: false}
    ]
  end
end
