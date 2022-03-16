defmodule Membrane.FFmpeg.SWResample.Mixfile do
  use Mix.Project

  @github_url "https://github.com/membraneframework/membrane_ffmpeg_swresample_plugin"
  @version "0.11.0"

  def project do
    [
      app: :membrane_ffmpeg_swresample_plugin,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: """
      Plugin performing audio conversion, resampling and channel mixing.
      Uses SWResample module of [FFmpeg](https://www.ffmpeg.org/) library.
      """,
      package: package(),
      name: "Membrane FFmpeg SWResample plugin",
      output_url: @github_url,
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.FFmpeg.SWResample]
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
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
      {:membrane_core, "~> 0.9.0"},
      {:membrane_raw_audio_format, "~> 0.8.0"},
      {:bunch, "~> 1.3.0"},
      {:unifex, "~> 0.7.0"},
      {:membrane_common_c, "~> 0.11.0"},
      {:bundlex, "~> 0.5.0"},
      # Testing
      {:mockery, "~> 2.1", runtime: false},
      # Development
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false}
    ]
  end
end
