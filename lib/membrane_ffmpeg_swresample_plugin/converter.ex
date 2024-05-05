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

  @supported_sample_format [:u8, :s16le, :s32le, :f32le, :f64le]
  @supported_channels [1, 2]

  def_output_pad :output,
    accepted_format:
      %RawAudio{sample_format: format, channels: channels}
      when format in @supported_sample_format and channels in @supported_channels

  def_input_pad :input,
    accepted_format:
      any_of(
        %RawAudio{sample_format: format, channels: channels}
        when format in @supported_sample_format and channels in @supported_channels,
        %RemoteStream{content_format: format} when format in [nil, RawAudio],
        %RawAudio{sample_format: :s24le, channels: channels} when channels in @supported_channels
      )

  def_options input_stream_format: [
                spec: RawAudio.t() | nil,
                default: nil,
                description: """
                Stream format for the input pad. If set to nil (default value),
                stream format is assumed to be received through the pad. If explicitly set to some
                stream format, it cannot be changed by stream format received through the pad.
                """
              ],
              output_stream_format: [
                spec: RawAudio.t(),
                description: """
                Audio stream format for output pad
                """
              ]

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    case options.input_stream_format do
      %RawAudio{} -> :ok
      nil -> :ok
      _other -> raise ":input_stream_format must be nil or %RawAudio{}"
    end

    case options.output_stream_format do
      %RawAudio{} -> :ok
      _other -> raise ":output_stream_format must be %RawAudio{}"
    end

    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        native: nil,
        queue: <<>>,
        input_stream_format_provided?: options.input_stream_format != nil,
        pts_queue: []
      })

    {[], state}
  end

  @impl true
  def handle_setup(_ctx, %{input_stream_format_provided?: false} = state), do: {[], state}

  def handle_setup(_ctx, state) do
    native = mk_native!(state.input_stream_format, state.output_stream_format)
    {[], %{state | native: native}}
  end

  @impl true
  def handle_stream_format(:input, %RemoteStream{}, _ctx, %{input_stream_format_provided?: false}) do
    raise """
    Cannot handle RemoteStream without explicitly providing `input_stream_format` via element options
    """
  end

  @impl true
  def handle_stream_format(
        :input,
        %RemoteStream{},
        _ctx,
        %{input_stream_format: stored_stream_format} = state
      ) do
    native = mk_native!(stored_stream_format, state.output_stream_format)
    state = %{state | native: native}
    {[stream_format: {:output, state.output_stream_format}], state}
  end

  @impl true
  def handle_stream_format(:input, stream_format, _ctx, %{
        input_stream_format_provided?: true,
        input_stream_format: stored_stream_format
      })
      when stored_stream_format != stream_format do
    raise """
    Received stream_format #{inspect(stream_format)} are different then the one defined in options #{inspect(stored_stream_format)}.
    If you want to allow converter to accept different input stream formats dynamically, use `nil` as input_stream_format.
    """
  end

  @impl true
  def handle_stream_format(:input, %RawAudio{} = stream_format, _ctx, state) do
    native = mk_native!(stream_format, state.output_stream_format)
    state = %{state | native: native, input_stream_format: stream_format}
    {[stream_format: {:output, state.output_stream_format}], state}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[stream_format: {:output, state.output_stream_format}], state}
  end

  @impl true
  def handle_buffer(:input, %Buffer{payload: payload, pts: input_pts}, _ctx, state) do
    input_frame_size = RawAudio.frame_size(state.input_stream_format)

    expected_output_frames =
      (byte_size(payload) * state.output_stream_format.sample_rate /
         (input_frame_size * state.input_stream_format.sample_rate))
      |> round() |> trunc()

    state =
      Map.update!(state, :pts_queue, fn pts_queue ->
        pts_queue ++ [{input_pts, expected_output_frames}]
      end)

    conversion_result =
      convert!(state.native, input_frame_size, payload, state.queue)

    case conversion_result do
      {<<>>, queue} ->
        {[], %{state | queue: queue}}

      # here I assume that it's impossible to get not integer number of converted frames
      {converted, queue} ->
        converted_frames_count =
          byte_size(converted) / RawAudio.frame_size(state.output_stream_format) |> trunc()

        {state, out_pts} = update_pts_queue(state, converted_frames_count)

        {[buffer: {:output, %Buffer{payload: converted, pts: out_pts}}], %{state | queue: queue}}
    end
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, %{native: nil} = state) do
    {[end_of_stream: :output], state}
  end

  def handle_end_of_stream(:input, _ctx, state) do
    dropped_bytes = byte_size(state.queue)

    if dropped_bytes > 0 do
      Membrane.Logger.warning(
        "Dropping enqueued #{dropped_bytes} on EoS. It's possible that the stream was ended abrubtly or the provided formats are invalid."
      )
    end

    case flush!(state.native) do
      <<>> ->
        {[end_of_stream: :output], %{state | queue: <<>>}}

      # here I assume that it's impossible to get not integer number of converted frames
      converted ->
        converted_frames_count =
          byte_size(converted) / RawAudio.frame_size(state.output_stream_format) |> trunc()

        {state, out_pts} = update_pts_queue(state, converted_frames_count)

        {[
           buffer: {:output, %Buffer{payload: converted, pts: out_pts}},
           end_of_stream: :output
         ], %{state | queue: <<>>}}
    end
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

  defp update_pts_queue(state, converted_frames_count) do
    # IO.inspect(state.pts_queue)
    [{out_pts, expected_frames} | rest] = state.pts_queue

    cond do
      converted_frames_count < expected_frames ->
        {%{state | pts_queue: [{out_pts, expected_frames - converted_frames_count}] ++ rest},
         out_pts}
      converted_frames_count > expected_frames ->
        IO.inspect("converted_frames_count #{converted_frames_count} expected_frames #{expected_frames}")
        remaining_frames_count = converted_frames_count - expected_frames
        IO.inspect(rest)
        {mapped, _acc} = rest |> Enum.flat_map_reduce(remaining_frames_count, fn x, acc ->
          {pts, frames} = x
          IO.inspect("pts #{pts} frames #{frames} acc #{acc}")
          cond do
            acc == 0 ->
              {[{pts, frames}], 0}
            acc < frames ->
              {[{pts, frames - acc}], 0}
            true ->
              {[nil], acc - frames}
          end
        end)
        filtered = mapped |> Enum.reject(fn x -> x == nil end)
        {%{state | pts_queue: filtered}, out_pts}
      true ->
        {%{state | pts_queue: rest}, out_pts}
    end
  end
  # defp update_pts_queue(state, converted_frames_count) do
  #   [{out_pts, expected_frames} | rest] = state.pts_queue
  #   IO.inspect("converted_frames_count #{converted_frames_count} expected_frames #{expected_frames}")
  #   cond do
  #     converted_frames_count < expected_frames ->
  #       {%{state | pts_queue: [{out_pts, expected_frames - converted_frames_count}] ++ rest}, out_pts}
  #     converted_frames_count > expected_frames ->
  #       remaining_frames_count = converted_frames_count - expected_frames
  #       {mapped, _acc} = rest |> Enum.flat_map_reduce(remaining_frames_count, fn x, acc ->
  #         {pts, frames} = x
  #         IO.inspect("pts #{pts} frames #{frames} acc #{acc}")
  #         cond do
  #           acc == 0 ->
  #             {[{pts, frames}], 0}
  #           acc < frames ->
  #             {[{pts, frames - acc}], 0}
  #           true ->
  #             {[nil], acc - frames}
  #         end
  #       end)
  #       filtered = mapped |> Enum.reject(fn x -> x == nil end)
  #       {%{state | pts_queue: filtered}, out_pts}
  #     true ->
  #       {%{state | pts_queue: rest}, out_pts}
  #   end
  # end
end
