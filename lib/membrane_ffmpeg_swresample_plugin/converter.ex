defmodule Membrane.FFmpeg.SWResample.Converter do
  @moduledoc """
  This element performs audio conversion/resampling/channel mixing, using SWResample
  module of FFmpeg library.
  """

  use Membrane.Filter
  import Mockery.Macro

  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.{Buffer, RawAudio, RemoteStream}

  @supported_format [:u8, :s16le, :s32le, :f32le, :f64le]
  @supported_channels [1, 2]

  def_output_pad :output,
    demand_mode: :auto,
    accepted_format:
      %RawAudio{sample_format: format, channels: channels}
      when format in @supported_format and channels in @supported_channels

  def_input_pad :input,
    demand_mode: :auto,
    demand_unit: :bytes,
    accepted_format:
      any_of(
        %RawAudio{sample_format: format, channels: channels}
        when format in @supported_format and channels in @supported_channels,
        %RemoteStream{content_format: format} when format in [nil, RawAudio],
        %RawAudio{sample_format: :s24le, channels: channels} when channels in @supported_channels
      )

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
    case options.input_caps do
      %RawAudio{} -> :ok
      nil -> :ok
      _other -> raise ":input_caps must be nil or %RawAudio{}"
    end

    case options.output_caps do
      %RawAudio{} -> :ok
      _other -> raise ":output_caps must be %RawAudio{}"
    end

    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        native: nil,
        queue: <<>>,
        input_caps_provided?: options.input_caps != nil
      })

    {[], state}
  end

  @impl true
  def handle_setup(_ctx, %{input_caps_provided?: false} = state), do: {[], state}

  def handle_setup(_ctx, state) do
    native = mk_native!(state.input_caps, state.output_caps)
    {[caps: {:output, state.output_caps}], %{state | native: native}}
  end

  @impl true
  def handle_caps(:input, %RemoteStream{}, _ctx, %{input_caps_provided?: false}) do
    raise """
    Cannot handle RemoteStream without explicitly providing `input_caps` via element options
    """
  end

  @impl true
  def handle_caps(:input, %RemoteStream{}, _ctx, %{input_caps: stored_caps} = state) do
    native = mk_native!(stored_caps, state.output_caps)
    state = %{state | native: native}
    {[caps: {:output, state.output_caps}], state}
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
  def handle_caps(:input, %RawAudio{} = caps, _ctx, state) do
    native = mk_native!(caps, state.output_caps)
    state = %{state | native: native, input_caps: caps}
    {[caps: {:output, state.output_caps}], state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload}, _ctx, state) do
    conversion_result =
      convert!(state.native, RawAudio.frame_size(state.input_caps), payload, state.queue)

    case conversion_result do
      {<<>>, queue} ->
        {[], %{state | queue: queue}}

      {converted, queue} ->
        {[buffer: {:output, %Buffer{payload: converted}}], %{state | queue: queue}}
    end
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    dropped_bytes = byte_size(state.queue)

    if dropped_bytes > 0 do
      Membrane.Logger.warn(
        "Dropping enqueued #{dropped_bytes} on EoS. It's possible that the stream was ended abrubtly or the provided formats are invalid."
      )
    end

    case flush!(state.native) do
      <<>> ->
        {[end_of_stream: :output], %{state | queue: <<>>}}

      converted ->
        {[buffer: {:output, %Buffer{payload: converted}, end_of_stream: :output}],
         %{state | queue: <<>>}}
    end
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {[], %{state | native: nil}}
  end

  defp mk_native!(
         %RawAudio{
           sample_format: in_sample_format,
           sample_rate: input_rate,
           channels: input_channels
         } = input_format,
         %RawAudio{
           sample_format: out_sample_format,
           sample_rate: out_rate,
           channels: out_channels
         } = out_format
       ) do
    mockable(Native).create(
      in_sample_format |> RawAudio.SampleFormat.serialize(),
      input_rate,
      input_channels,
      out_sample_format |> RawAudio.SampleFormat.serialize(),
      out_rate,
      out_channels
    )
    |> case do
      {:ok, native} ->
        native

      {:error, reason} ->
        raise """
        Error while initializing native converter: #{inspect(reason)}
        Input format: #{inspect(input_format)}
        Output format: #{inspect(out_format)}
        """
    end
  end

  defp convert!(native, frame_size, payload, queue)
       when byte_size(queue) + byte_size(payload) > 2 * frame_size do
    {payload, q} =
      (queue <> payload)
      |> Bunch.Binary.split_int_part(frame_size)

    case mockable(Native).convert(payload, native) do
      {:ok, result} -> {result, q}
      {:error, reason} -> raise "Error while converting payload: #{inspect(reason)}"
    end
  end

  defp convert!(_native, _frame_size, payload, queue), do: {<<>>, queue <> payload}

  defp flush!(native) do
    case mockable(Native).convert("", native) do
      {:ok, result} -> result
      {:error, reason} -> raise "Error while flushing converter: #{inspect(reason)}"
    end
  end
end
