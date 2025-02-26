defmodule Membrane.FFmpeg.SWResample.PtsForwardTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  alias Membrane.FFmpeg.SWResample.Converter
  alias Membrane.{RawAudio, MP3, Testing}

  @pts_multiplier 31_250_000

  test "end of stream nil pts handle test" do
    spec =
      child(:file_source, %Membrane.File.Source{location: "test/fixtures/sample.mp3"})
      |> child(:decoder_mp3, MP3.MAD.Decoder)
      |> child(:converter, %Converter{
        input_stream_format: %RawAudio{channels: 2, sample_format: :s24le, sample_rate: 48_000},
        output_stream_format: %RawAudio{channels: 1, sample_format: :s16le, sample_rate: 44_100}
      })
      |> child(:sink, Membrane.Testing.Sink)

    pipeline = Testing.Pipeline.start_link_supervised!(spec: spec)

    assert_end_of_stream(pipeline, :sink)
    Testing.Pipeline.terminate(pipeline)
  end

  test "pts forward test" do
    input_stream_format = %RawAudio{sample_format: :s16le, sample_rate: 16_000, channels: 2}
    output_stream_format = %RawAudio{sample_format: :s32le, sample_rate: 32_000, channels: 2}
    # 32 frames * 2048 bytes
    path = "test/fixtures/input_s16le_stereo_16khz.raw"

    spec = [
      child(:source, %Membrane.Testing.Source{output: buffers_from_file(path)})
      |> child(:resampler, %Converter{
        input_stream_format: input_stream_format,
        output_stream_format: output_stream_format
      })
      |> child(:sink, Membrane.Testing.Sink)
    ]

    pipeline = Testing.Pipeline.start_link_supervised!(spec: spec)
    # converter buffers some data and first released buffers are a bit smaller than input data,
    # that's why we expect first 2 to have the same pts == 0
    assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{pts: out_pts})
    assert out_pts == 0

    Enum.each(0..31, fn index ->
      assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{pts: out_pts})
      assert out_pts == index * @pts_multiplier
    end)

    assert_end_of_stream(pipeline, :sink)
    Testing.Pipeline.terminate(pipeline)
  end

  defp buffers_from_file(path) do
    binary = File.read!(path)

    split_binary(binary)
    |> Enum.with_index()
    |> Enum.map(fn {payload, index} ->
      %Membrane.Buffer{
        payload: payload,
        pts: index * @pts_multiplier
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
