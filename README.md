# Membrane.Element.FFmpeg.SWResample

This element performs audio conversion, resampling and channel mixing, using SWResample module of FFmpeg library.

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