defmodule Membrane.Element.FFmpeg.SWResample.Converter do
  @moduledoc """
  This element performs audio conversion/resampling/channel mixing, using SWResample
  module of FFmpeg library.
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.Raw, as: Caps
  alias Membrane.Buffer
  alias Membrane.Caps.Matcher
  alias __MODULE__.Native
  import Mockery.Macro

  @supported_caps {Caps,
                   format: Matcher.one_of([:u8, :s16le, :s32le, :f32le, :f64le]),
                   channels: Matcher.one_of([1, 2])}

  def_output_pad :output, caps: @supported_caps

  def_input_pad :input,
    demand_unit: :bytes,
    caps: [@supported_caps, {Caps, format: :s24le, channels: one_of([1, 2])}]

  def_options input_caps: [
                type: :caps,
                spec: Caps.t() | nil,
                default: nil,
                description: """
                Caps for the input pad. If set to nil (default value),
                caps are assumed to be received through the pad. If explicitly set to some
                caps, they cannot be changed by caps received through the pad.
                """
              ],
              output_caps: [
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
  def handle_stopped_to_prepared(_ctx, %{input_caps: nil} = state), do: {:ok, state}

  def handle_stopped_to_prepared(_ctx, state) do
    with {:ok, native} <- mk_native(state.input_caps, state.output_caps) do
      {{:ok, caps: {:output, state.output_caps}}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_caps(:input, caps, _ctx, %{input_caps: input_caps} = state)
      when input_caps in [nil, caps] do
    with {:ok, native} <- mk_native(caps, state.output_caps) do
      {{:ok, caps: {:output, state.output_caps}, redemand: :output}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_caps(:input, caps, _ctx, %{input_caps: stored_caps}) do
    raise """
    Received caps #{inspect(caps)} are different then defined in options #{inspect(stored_caps)}.
    If you want to allow converter to accept different input caps dynamically, use `nil` as input_caps.
    """
  end

  @impl true
  def handle_demand(:output, _size, _unit, _ctx, %{native: nil} = state), do: {:ok, state}

  def handle_demand(:output, size, :bytes, ctx, %{input_caps: input_caps} = state) do
    size =
      size
      |> Caps.bytes_to_time(ctx.pads.output.caps)
      |> Caps.time_to_bytes(ctx.pads.input.caps || input_caps)

    {{:ok, demand: {:input, size}}, state}
  end

  def handle_demand(:output, n_buffers, :buffers, _ctx, state) do
    size = n_buffers * Caps.frames_to_bytes(state.frames_per_buffer, state.input_caps)
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload}, ctx, %{native: native, queue: q} = state) do
    caps = ctx.pads.input.caps || state.input_caps
    frame_size = (caps |> Caps.sample_size()) * caps.channels

    with {:ok, {result, q}} when byte_size(result) > 0 <- convert(native, frame_size, payload, q) do
      {{:ok, buffer: {:output, %Buffer{payload: result}}, redemand: :output}, %{state | queue: q}}
    else
      {:ok, {<<>>, q}} -> {{:ok, redemand: :output}, %{state | queue: q}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {:ok, %{state | native: nil}}
  end

  defp mk_native(
         %Caps{format: input_format, sample_rate: input_rate, channels: input_channels},
         %Caps{format: out_format, sample_rate: out_rate, channels: out_channels}
       ) do
    mockable(Native).create(
      input_format |> Caps.Format.serialize(),
      input_rate,
      input_channels,
      out_format |> Caps.Format.serialize(),
      out_rate,
      out_channels
    )
  end

  defp convert(native, frame_size, payload, queue)
       when byte_size(queue) + byte_size(payload) > 2 * frame_size do
    {payload, q} =
      (queue <> payload)
      |> Bunch.Binary.split_int_part(frame_size)

    with {:ok, result} <- mockable(Native).convert(payload, native) do
      {:ok, {result, q}}
    end
  end

  defp convert(_native, _frame_size, payload, queue), do: {:ok, {<<>>, queue <> payload}}
end
