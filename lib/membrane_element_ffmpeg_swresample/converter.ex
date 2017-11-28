defmodule Membrane.Element.FFmpeg.SWResample.Converter do
  @moduledoc """
  This element performs audio conversion/resampling/channel mixing, using SWResample
  module of FFmpeg library.
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.Raw, as: Caps
  alias __MODULE__.{Options, Native}
  alias Membrane.Buffer

  # @supported_caps [
  #   %Caps{format: :f64le, channels: 1},
  #   %Caps{format: :f32le, channels: 1},
  #   %Caps{format: :s32le, channels: 1},
  #   %Caps{format: :s16le, channels: 1},
  #   %Caps{format: :u8,    channels: 1},
  #   %Caps{format: :f64le, channels: 2},
  #   %Caps{format: :f32le, channels: 2},
  #   %Caps{format: :s32le, channels: 2},
  #   %Caps{format: :s16le, channels: 2},
  #   %Caps{format: :u8,    channels: 2},
  # ]

  def_known_source_pads %{
    :source => {:always, :pull, :any}
  }

  def_known_sink_pads %{
    :sink => {:always, {:pull, demand_in: :bytes}, :any},
  }

  def handle_init(%Options{sink_caps: sink_caps, source_caps: source_caps}) do
    {:ok, %{sink_caps: sink_caps, source_caps: source_caps, native: nil}}
  end

  def handle_prepare(:stopped, %{sink_caps: nil} = state), do:
    {:ok, state}

  def handle_prepare(:stopped, state) do
    with {:ok, native} <- mk_native(state.sink_caps, state.source_caps)
    do
      {{:ok, caps: {:source, state.source_caps}}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_prepare(playback, state), do:
    super(playback, state)

  def handle_caps(:sink, caps, _, state) do
    with {:ok, native} <- mk_native(caps, state.source_caps)
    do
      {{:ok, caps: {:source, state.source_caps}, redemand: :source}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_demand(:source, _size, _, %{native: nil} = state), do:
    {:ok, state}

  def handle_demand(:source, size, _, state), do:
    {{:ok, demand: {:sink, size}}, state}

  def handle_process1 :sink, _caps, %Buffer{payload: payload} = buffer, %{native: native} = state do
    with {:ok, result} when byte_size(result) > 0
      <- Native.convert(native, payload)
    do
      {{:ok, buffer: {:source, %Buffer{buffer | payload: result}}}, state}
    else
      {:ok, <<>>} -> {:ok, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp mk_native(
    %Caps{format: sink_format, sample_rate: sink_rate, channels: sink_channels},
    %Caps{format: src_format, sample_rate: src_rate, channels: src_channels}
  )do
    Native.create(
      sink_format |> Caps.SerializedFormat.from_atom, sink_rate, sink_channels,
      src_format |> Caps.SerializedFormat.from_atom, src_rate, src_channels
    )
  end

end
