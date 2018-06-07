# Membrane.Element.FFmpeg.SWResample

[![Build Status](https://travis-ci.com/membraneframework/membrane-element-ffmpeg-swresample.svg?branch=master)](https://travis-ci.com/membraneframework/membrane-element-ffmpeg-swresample)

Element of [Membrane Multimedia Framework](https://membraneframework.org) performing audio conversion, resampling and channel mixing, using SWResample module of [FFmpeg](https://www.ffmpeg.org/) library.

Documentation is available at [HexDocs](https://hexdocs.pm/membrane_element_portaudio/)

## Installation

Add the following line to your `deps` in `mix.exs`. Run `mix deps.get`.

```elixir
{:membrane_element_ffmpeg_swresample, "~> 0.1"}
```

You also need to have [FFmpeg](https://www.ffmpeg.org/) library installed.
For usage on windows, see `Using on Windows` section below.

## Sample usage

```elixir
defmodule Resampling.Pipeline do
  use Membrane.Pipeline
  alias Pipeline.Spec
  alias Membrane.Element.File
  alias Membrane.Element.FFmpeg.SWResample.Converter
  alias Membrane.Caps.Audio.Raw

  @doc false
  @impl true
  def handle_init(_) do
    children = [
      file_src: %File.Source{location: "/tmp/some_samples.raw"},
      converter: %Converter{
        sink_caps: %Raw{channels: 2, format: :s24le, sample_rate: 48_000},
        source_caps: %Raw{channels: 2, format: :f32le, sample_rate: 44_100}
      },
      file_sink: %File.Sink{location: "/tmp/out.raw"},
    ]
    links = %{
      {:file_src, :source} => {:converter, :sink},
      {:converter, :source} => {:file_sink, :sink}
    }

    {{:ok, %Spec{children: children, links: links}}, %{}}
  end
end
```

## Using on Windows

It is possible to compile and use this element on Windows platform. That requires:

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
