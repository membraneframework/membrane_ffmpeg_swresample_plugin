defmodule Membrane.FFmpeg.SWResample.PtsForwardTest do
  use ExUnit.Case

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  alias Membrane.FFmpeg.SWResample.Converter
  alias Membrane.{RawAudio, Testing}

  @pts_multiplier 31_250_000

  test "pts nil forward test" do
    input_stream_format = %RawAudio{sample_format: :s16le, sample_rate: 16_000, channels: 2}
    output_stream_format = %RawAudio{sample_format: :s32le, sample_rate: 32_000, channels: 2}

    spec = [
      child(:source, %Membrane.Testing.Source{output: buffers_from_file(false)})
      |> child(:resampler, %Converter{
        input_stream_format: input_stream_format,
        output_stream_format: output_stream_format
      })
      |> child(:sink, Membrane.Testing.Sink)
    ]

    pipeline = Testing.Pipeline.start_link_supervised!(spec: spec)
    assert_sink_buffer(pipeline, :sink, _buffer)

    Enum.each(0..31, fn _index ->
      assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{pts: out_pts})
      assert out_pts == nil
    end)

    assert_end_of_stream(pipeline, :sink)
    Testing.Pipeline.terminate(pipeline)
  end

  test "pts forward test" do
    input_stream_format = %RawAudio{sample_format: :s16le, sample_rate: 16_000, channels: 2}
    output_stream_format = %RawAudio{sample_format: :s32le, sample_rate: 32_000, channels: 2}

    spec = [
      child(:source, %Membrane.Testing.Source{output: buffers_from_file(true)})
      |> child(:resampler, %Converter{
        input_stream_format: input_stream_format,
        output_stream_format: output_stream_format
      })
      |> child(:sink, Membrane.Testing.Sink)
    ]

    pipeline = Testing.Pipeline.start_link_supervised!(spec: spec)
    assert_sink_buffer(pipeline, :sink, _buffer)

    Enum.each(0..30, fn index ->
      assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{pts: out_pts})
      assert out_pts == index * @pts_multiplier
    end)

    assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{pts: last_out_pts})
    assert last_out_pts == 30 * @pts_multiplier

    assert_end_of_stream(pipeline, :sink)
    Testing.Pipeline.terminate(pipeline)
  end

  defp buffers_from_file(with_pts?) do
    # 32 frames * 2048 bytes
    binary = File.read!("test/fixtures/input_s16le_stereo_16khz.raw")

    split_binary(binary)
    |> Enum.with_index()
    |> Enum.map(fn {payload, index} ->
      %Membrane.Buffer{
        payload: payload,
        pts: if with_pts? do
          index * @pts_multiplier
        else
          nil
        end
      }
    end)
  end

  @spec split_binary(binary(), list(binary())) :: list(binary())
  def split_binary(binary, acc \\ [])

  def split_binary(<<binary::binary-size(2048), rest::binary>>, acc) do
    split_binary(rest, [binary] ++ acc)
  end

  def split_binary(rest, acc) when byte_size(rest) <= 2048 do
    Enum.reverse(acc) ++ [rest]
  end
end
