# Membrane FFmpeg SWResample plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_ffmpeg_swresample_plugin.svg)](https://hex.pm/packages/membrane_ffmpeg_swresample_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_ffmpeg_swresample_plugin/)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_ffmpeg_swresample_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_ffmpeg_swresample_plugin)

Plugin performing audio conversion, resampling and channel mixing, using SWResample module of [FFmpeg](https://www.ffmpeg.org/) library.

It is a part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

Add the following line to your `deps` in `mix.exs`. Run `mix deps.get`.

```elixir
{:membrane_ffmpeg_swresample_plugin, "~> 0.7.1"}
```

You also need to have [FFmpeg](https://www.ffmpeg.org/) library installed.
For usage on windows, see `Using on Windows` section below.

## Sample usage

```elixir
defmodule Resampling.Pipeline do
  use Membrane.Pipeline

  alias Membrane.Element.File
  alias Membrane.FFmpeg.SWResample.Converter
  alias Membrane.Caps.Audio.Raw

  @doc false
  @impl true
  def handle_init(_) do
    children = [
      file_src: %File.Source{location: "/tmp/input.raw"},
      converter: %Converter{
        input_caps: %Raw{channels: 2, format: :s24le, sample_rate: 48_000},
        output_caps: %Raw{channels: 2, format: :f32le, sample_rate: 44_100}
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

## Using on Windows

It is possible to compile and use this plugin on Windows platform. That requires:

* Git-LFS to clone binaries placed in `ext/windows` directory
* Visual C++ Build Tools with Windows SDK (tested on build tools 2015 and SDK for Windows 10)
* FFMpeg 3.4.2 DLLs - `avutil-55.dll` and `swresample-2.dll`
  (64-bit version abvailable [here](https://ffmpeg.zeranoe.com/builds/win64/shared/ffmpeg-3.4.2-win64-shared.zip),
  32-bit [here](https://ffmpeg.zeranoe.com/builds/win32/shared/ffmpeg-3.4.2-win32-shared.zip)).
  The DLLs have to be available at runtime. This can be achieved in a couple of ways:
  * adding directory with DLLs to `PATH` environment variable
  * placing them in current directory (where you start `mix run`)
  * placing them in the directory where erlang executable is located
  * making them available system-wide by placing in system (`C:\Windows\System32`, `C:\Windows\SysWOW64`) or Windows (`C:\Windows`) directory

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
