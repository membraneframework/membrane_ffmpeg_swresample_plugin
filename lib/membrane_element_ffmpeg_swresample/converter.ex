defmodule Membrane.Element.FFmpeg.SWResample.Converter do
  @moduledoc """
  This element performs audio conversion/resampling/channel mixing, using SWResample
  module of FFmpeg library.
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.Raw, as: Caps
  alias Membrane.Buffer
  alias Membrane.Caps.Matcher
  import Mockery.Macro
  use Bunch

  @supported_caps {Caps,
                   format: Matcher.one_of([:u8, :s16le, :s32le, :f32le, :f64le]),
                   channels: Matcher.one_of([1, 2])}

  def_output_pads output: [caps: @supported_caps]

  def_input_pads input: [
                   demand_unit: :bytes,
                   caps: [@supported_caps, {Caps, format: :s24le, channels: one_of([1, 2])}]
                 ]

  def_options input_caps: [
                type: :caps,
                spec: Caps.t() | nil,
                default: nil,
                description: """
                Audio caps for input pad. If set to nil (default value),
                caps are assumed to be received from :input. If explicitly set to some
                caps, they cannot be changed by caps received from :input.
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
  def handle_caps(:input, caps, _, %{input_caps: nil} = state) do
    do_handle_caps(caps, state)
  end

  def handle_caps(:input, caps, _ctx, %{input_caps: caps} = state) do
    do_handle_caps(caps, state)
  end

  def handle_caps(:input, caps, _ctx, %{input_caps: stored_caps}) when caps != stored_caps do
    raise """
    Received caps are different then defined in options. If you want to allow converter
    to accept different input caps dynamically, use `nil` as input_caps.
    """
  end

  @impl true
  def handle_demand(:output, _size, _unit, _ctx, %{native: nil} = state), do: {:ok, state}

  def handle_demand(:output, size, :bytes, _ctx, state),
    do: {{:ok, demand: {:input, size}}, state}

  def handle_demand(:output, n_buffers, :buffers, _ctx, state) do
    size = n_buffers * Caps.frames_to_bytes(state.frames_per_buffer, state.input_caps)
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload}, %{caps: caps}, state)
      when caps != nil do
    process_payload(payload, caps, state)
  end

  def handle_process(:input, %Buffer{payload: payload}, _ctx, %{input_caps: caps} = state) do
    process_payload(payload, caps, state)
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {:ok, %{state | native: nil}}
  end

  defp do_handle_caps(caps, state) do
    with {:ok, native} <- mk_native(caps, state.output_caps) do
      {{:ok, caps: {:output, state.output_caps}, redemand: :output}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp process_payload(payload, caps, %{native: native, queue: q} = state) do
    frame_size = (caps |> Caps.sample_size()) * caps.channels

    with {:ok, {result, q}} when byte_size(result) > 0 <- convert(native, frame_size, payload, q) do
      {{:ok, buffer: {:output, %Buffer{payload: result}}}, %{state | queue: q}}
    else
      {:ok, {<<>>, q}} -> {:ok, %{state | queue: q}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp mk_native(
         %Caps{format: input_format, sample_rate: input_rate, channels: input_channels},
         %Caps{format: out_format, sample_rate: out_rate, channels: out_channels}
       ) do
    native().create(
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
      |> binary_int_rem(frame_size)

    with {:ok, result} <- native().convert(payload, native) do
      {:ok, {result, q}}
    end
  end

  defp convert(_native, _frame_size, payload, queue), do: {:ok, {<<>>, queue <> payload}}

  defp binary_int_rem(b, d) when is_binary(b) and is_integer(d) do
    len = b |> byte_size |> int_part(d)
    <<b::binary-size(len), r::binary>> = b
    {b, r}
  end

  defp native(), do: mockable(__MODULE__.Native)
end
