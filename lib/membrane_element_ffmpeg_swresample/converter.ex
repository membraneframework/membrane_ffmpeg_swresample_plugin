defmodule Membrane.Element.FFmpeg.SWResample.ConverterOptions do
  @moduledoc """
  Options passed to converter. If sink_caps field equals Nil, those caps are
  assumed to be received through :sink.
  """
  defstruct \
    sink_caps: Nil,
    source_caps: %Membrane.Caps.Audio.Raw{}
end

defmodule Membrane.Element.FFmpeg.SWResample.Converter do
  @moduledoc """
  This element performs audio conversion/resampling/channel mixing, using SWResample
  module of FFmpeg library.
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.Raw, as: Caps
  alias Membrane.Element.FFmpeg.SWResample.ConverterNative
  alias Membrane.Element.FFmpeg.SWResample.ConverterOptions

  @supported_caps [
    %Caps{format: :f64le, channels: 1},
    %Caps{format: :f32le, channels: 1},
    %Caps{format: :s32le, channels: 1},
    %Caps{format: :s16le, channels: 1},
    %Caps{format: :u8,    channels: 1},
    %Caps{format: :f64le, channels: 2},
    %Caps{format: :f32le, channels: 2},
    %Caps{format: :s32le, channels: 2},
    %Caps{format: :s16le, channels: 2},
    %Caps{format: :u8,    channels: 2},
  ]

  def_known_source_pads %{
    :source => {:always, @supported_caps}
  }

  def_known_sink_pads %{
    :sink => {:always, @supported_caps},
    :source_caps => {:always, @supported_caps},
  }

  def handle_init %ConverterOptions{sink_caps: sink_caps, source_caps: source_caps} do
    {:ok, %{sink_caps: sink_caps, source_caps: source_caps, native: nil}}
  end

  defp handle_all_caps_supplied(
    %Caps{format: sink_format, sample_rate: sink_rate, channels: sink_channels} = sink_caps,
    %Caps{format: src_format, sample_rate: src_rate, channels: src_channels} = src_caps,
    state
  )do

    case ConverterNative.create(
      sink_format |> Caps.SerializedFormat.from_atom, sink_rate, sink_channels,
      src_format |> Caps.SerializedFormat.from_atom, src_rate, src_channels
    )do
      {:ok, native} -> {:ok, [{:caps, {:source, src_caps}}], %{state | native: native}}
      {:error, reason} -> {:error, reason, state}
    end
  end

  def handle_caps :sink, sink_caps, state do
    {:ok, %{state | sink_caps: sink_caps}}
  end
  def handle_caps :source_caps, source_caps, state do
    {:ok, %{state | source_caps: source_caps}}
  end

  def handle_buffer :sink, caps, %Membrane.Buffer{} = buffer, %{sink_caps: sink_caps, source_caps: source_caps, native: nil} = state do
    {:ok, _com, state} = handle_all_caps_supplied(sink_caps, source_caps, state)
    handle_buffer(:sink, caps, buffer, state)
  end
  def handle_buffer :sink, _caps, %Membrane.Buffer{payload: payload} = buffer, %{native: native} = state do
    case ConverterNative.convert native, payload do
      {:ok, <<>>} -> {:ok, state}
      {:ok, result} -> {:ok, [{:send, {:source, %Membrane.Buffer{buffer | payload: result}}}], state}
      {:error, desc} -> {:error, desc}
    end
  end

end
