defmodule Membrane.FFmpeg.SWResample.Converter do
  @moduledoc """
  This element performs audio conversion/resampling/channel mixing, using SWResample
  module of FFmpeg library.
  """

  use Membrane.Filter
  import Mockery.Macro

  alias Membrane.{RawAudio, Buffer}
  alias Membrane.Caps.Matcher
  alias __MODULE__.Native

  @supported_caps {RawAudio,
                   sample_format: Matcher.one_of([:u8, :s16le, :s32le, :f32le, :f64le]),
                   channels: Matcher.one_of([1, 2])}

  def_output_pad :output, demand_mode: :auto, caps: @supported_out_caps

  def_input_pad :input,
    demand_mode: :auto,
    demand_unit: :bytes,
    caps: [@supported_caps, {RawAudio, sample_format: :s24le, channels: one_of([1, 2])}]

  def_options input_caps: [
                type: :caps,
                spec: RawAudio.t() | nil,
                default: nil,
                description: """
                Caps for the input pad. If set to nil (default value),
                caps are assumed to be received through the pad. If explicitly set to some
                caps, they cannot be changed by caps received through the pad.
                """
              ],
              output_caps: [
                type: :caps,
                spec: RawAudio.t(),
                description: """
                Audio caps for source pad (output)
                """
              ]

  @impl true
  def handle_init(%__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        native: nil,
        queue: <<>>,
        input_caps_provided?: options.input_caps != nil
      })

    {:ok, state}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, %{input_caps_provided?: false} = state), do: {:ok, state}

  def handle_stopped_to_prepared(_ctx, state) do
    with {:ok, native} <- mk_native(state.input_caps, state.output_caps) do
      {{:ok, caps: {:output, state.output_caps}}, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_caps(:input, caps, _ctx, %{input_caps_provided?: true, input_caps: stored_caps})
      when stored_caps != caps do
    raise """
    Received caps #{inspect(caps)} are different then defined in options #{inspect(stored_caps)}.
    If you want to allow converter to accept different input caps dynamically, use `nil` as input_caps.
    """
  end

  @impl true
  def handle_caps(:input, caps, _ctx, state) do
    with {:ok, native} <- mk_native(caps, state.output_caps) do
      state = %{state | native: native, input_caps: caps}
      {{:ok, caps: {:output, state.output_caps}}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload}, _ctx, state) do
    conversion_result =
      convert(state.native, RawAudio.frame_size(state.input_caps), payload, state.queue)

    with {:ok, {result, queue}} when byte_size(result) > 0 <- conversion_result do
      {{:ok, buffer: {:output, %Buffer{payload: result}}}, %{state | queue: queue}}
    else
      {:ok, {<<>>, queue}} -> {:ok, %{state | queue: queue}}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {:ok, %{state | native: nil}}
  end

  defp mk_native(
         %RawAudio{
           sample_format: input_format,
           sample_rate: input_rate,
           channels: input_channels
         },
         %RawAudio{sample_format: out_format, sample_rate: out_rate, channels: out_channels}
       ) do
    mockable(Native).create(
      input_format |> RawAudio.SampleFormat.serialize(),
      input_rate,
      input_channels,
      out_format |> RawAudio.SampleFormat.serialize(),
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
