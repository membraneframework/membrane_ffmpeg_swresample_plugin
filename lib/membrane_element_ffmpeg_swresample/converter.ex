defmodule Membrane.Element.FFmpeg.SWResample.Converter do
  @moduledoc """
  This element performs audio conversion/resampling/channel mixing, using SWResample
  module of FFmpeg library.
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.Raw, as: Caps
  alias Membrane.Buffer
  alias Membrane.Caps.Matcher
  use Membrane.Helper

  @native Mockery.of(__MODULE__.Native)

  @supported_caps {Caps,
                   format: Matcher.one_of([:u8, :s16le, :s32le, :f32le, :f64le]),
                   channels: Matcher.range(1, 2)}

  def_known_source_pads source: {:always, :pull, @supported_caps}

  def_known_sink_pads sink:
                        {:always, {:pull, demand_in: :bytes},
                         [@supported_caps, {Caps, format: :s24le, channels: range(1, 2)}]}

  def_options sink_caps: [
                type: :caps,
                spec: Caps.t() | nil,
                default: nil,
                description: """
                Audio caps for sink pad (input). If set to nil (default value),
                caps are assumed to be received from :sink. If explicitly set to some
                caps, they cannot be changed by caps received from :sink.
                """
              ],
              source_caps: [
                type: :caps,
                spec: Caps.t(),
                description: """
                Audio caps for souce pad (output)
                """
              ],
              frames_per_buffer: [
                type: :integer,
                spec: pos_integer(),
                default: 2048,
                description: """
                Assumed number of raw audio frames in each buffer.
                Used when converting demand from buffers into bytes.
                """
              ]

  @impl true
  def handle_init(%__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        native: nil,
        queue: <<>>
      })

    {:ok, state}
  end

  @impl true
  def handle_prepare(:stopped, %{sink_caps: nil} = state), do: {:ok, state}

  def handle_prepare(:stopped, state) do
    with {:ok, native} <- mk_native(state.sink_caps, state.source_caps) do
      {{:ok, caps: {:source, state.source_caps}}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_prepare(playback, state), do: super(playback, state)

  @impl true
  def handle_caps(:sink, caps, _, %{sink_caps: nil} = state) do
    do_handle_caps(caps, state)
  end

  def handle_caps(:sink, caps, _, %{sink_caps: caps} = state) do
    do_handle_caps(caps, state)
  end

  def handle_caps(:sink, caps, _, %{sink_caps: stored_caps}) when caps != stored_caps do
    raise """
    Received caps are different then defined in options. If you want to allow converter
    to accept different sink caps dynamically, use `nil` as sink_caps.
    """
  end

  @impl true
  def handle_demand(:source, _size, _, _, %{native: nil} = state), do: {:ok, state}

  def handle_demand(:source, size, :bytes, _, state), do: {{:ok, demand: {:sink, size}}, state}

  def handle_demand(:source, n_buffers, :buffers, _, state) do
    size = n_buffers * Caps.frames_to_bytes(state.frames_per_buffer, state.sink_caps)
    {{:ok, demand: {:sink, size}}, state}
  end

  @impl true
  def handle_process1(:sink, %Buffer{payload: payload}, %{caps: caps}, state)
      when caps != nil do
    process_payload(payload, caps, state)
  end

  def handle_process1(:sink, %Buffer{payload: payload}, _, %{sink_caps: caps} = state) do
    process_payload(payload, caps, state)
  end

  @impl true
  def handle_stop(state) do
    {:ok, %{state | native: nil}}
  end

  defp do_handle_caps(caps, state) do
    with {:ok, native} <- mk_native(caps, state.source_caps) do
      {{:ok, caps: {:source, state.source_caps}, redemand: :source}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp process_payload(payload, caps, %{native: native, queue: q} = state) do
    frame_size = (caps |> Caps.sample_size()) * caps.channels

    with {:ok, {result, q}} when byte_size(result) > 0 <- convert(native, frame_size, payload, q) do
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
    @native.create(
      sink_format |> Caps.Format.serialize(),
      sink_rate,
      sink_channels,
      src_format |> Caps.Format.serialize(),
      src_rate,
      src_channels
    )
  end

  defp convert(native, frame_size, payload, queue)
       when byte_size(queue) + byte_size(payload) > 2 * frame_size do
    {payload, q} =
      (queue <> payload)
      |> binary_int_rem(frame_size)

    with {:ok, result} <- @native.convert(native, payload) do
      {:ok, {result, q}}
    end
  end

  defp convert(_native, _frame_size, payload, queue), do: {:ok, {<<>>, queue <> payload}}

  defp binary_int_rem(b, d) when is_binary(b) and is_integer(d) do
    len = b |> byte_size |> int_part(d)
    <<b::binary-size(len), r::binary>> = b
    {b, r}
  end
end
