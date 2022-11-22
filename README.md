# Membrane FFmpeg SWResample plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_ffmpeg_swresample_plugin.svg)](https://hex.pm/packages/membrane_ffmpeg_swresample_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_ffmpeg_swresample_plugin/)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_ffmpeg_swresample_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_ffmpeg_swresample_plugin)

Plugin performing audio conversion, resampling and channel mixing, using SWResample module of [FFmpeg](https://www.ffmpeg.org/) library.

It is a part of [Membrane Multimedia Framework](https://membrane.stream).

## Installation

Add the following line to your `deps` in `mix.exs`. Run `mix deps.get`.

```elixir
	{:membrane_ffmpeg_swresample_plugin, "~> 0.16.0"}
```

You also need to have [FFmpeg](https://www.ffmpeg.org/) library installed.

## Usage

The pipeline takes raw audio, converts the sample format from `s24le` to `f32le` and resamples
it to 44.1 kHz rate.

```elixir
defmodule Resampling.Pipeline do
  use Membrane.Pipeline

  alias Membrane.Element.File
  alias Membrane.FFmpeg.SWResample.Converter
  alias Membrane.RawAudio

  @doc false
  @impl true
  def handle_init(_) do
    children = [
      file_src: %File.Source{location: "/tmp/input.raw"},
      converter: %Converter{
        input_caps: %RawAudio{channels: 2, sample_format: :s24le, sample_rate: 48_000},
        output_caps: %RawAudio{channels: 2, sample_format: :f32le, sample_rate: 44_100}
      },
      file_sink: %File.Sink{location: "/tmp/output.raw"},
    ]

    links = [
      link(:file_src)
      |> to(:converter)
      |> to(:file_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
