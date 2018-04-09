defmodule Membrane.Element.FFmpeg.SWResample.Converter do
  @moduledoc """
  This element performs audio conversion/resampling/channel mixing, using SWResample
  module of FFmpeg library.
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.Raw, as: Caps
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Matcher
  use Membrane.Helper

  @supported_caps {Caps, format: Matcher.one_of([:u8, :s16le, :s32le, :f32le, :f64le]), channels: Matcher.one_of([1, 2])}

  def_known_source_pads source: {:always, :pull, @supported_caps}

  def_known_sink_pads sink: {:always, {:pull, demand_in: :bytes}, @supported_caps}

  def_options sink_caps: [
                type: :caps,
                spec: Caps.t | nil,
                default: nil,
                description: """
                Audio caps for sink pad (input). If set to nil (default value),
                caps are assumed to be received from :sink
                """
              ],
              source_caps: [
                type: :caps,
                description: """
                Audio caps for souce pad (output)
                """
              ]

  @impl true
  def handle_init(%__MODULE__{sink_caps: sink_caps, source_caps: source_caps}) do
    {:ok, %{
      sink_caps: sink_caps,
      source_caps: source_caps,
      native: nil,
      queue: <<>>,
    }}
  end

  @impl true
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

  @impl true
  def handle_caps(:sink, caps, _, state) do
    with {:ok, native} <- mk_native(caps, state.source_caps)
    do
      {{:ok, caps: {:source, state.source_caps}, redemand: :source}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_demand(:source, _size, :bytes, _, %{native: nil} = state), do:
    {:ok, state}

  def handle_demand(:source, size, :bytes, _, state), do:
    {{:ok, demand: {:sink, size}}, state}

  @impl true
  def handle_process1(
    :sink,
    %Buffer{payload: payload},
    %{caps: caps},
    %{native: native, queue: q} = state
  ) do
    frame_size = (caps |> Caps.sample_size) * caps.channels
    with {:ok, {result, q}} when byte_size(result) > 0
      <- convert(native, frame_size, payload, q)
    do
      {{:ok, buffer: {:source, %Buffer{payload: result}}}, %{state | queue: q}}
    else
      {:ok, {<<>>, q}} -> {:ok, %{state | queue: q}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp mk_native(
    %Caps{format: sink_format, sample_rate: sink_rate, channels: sink_channels},
    %Caps{format: src_format, sample_rate: src_rate, channels: src_channels}
  ) do
    Native.create(
      sink_format |> Caps.Format.serialize, sink_rate, sink_channels,
      src_format |> Caps.Format.serialize, src_rate, src_channels
    )
  end

  defp convert(native, frame_size, payload, queue)
  when byte_size(queue) + byte_size(payload) > 2*frame_size do
    {payload, q} = (queue <> payload)
      |> Helper.Binary.int_rem(frame_size)

    with {:ok, result} <- Native.convert(native, payload)
    do {:ok, {result, q}}
    end
  end

  defp convert(_native, _frame_size, payload, queue), do:
    {:ok, {<<>>, queue <> payload}}

end
