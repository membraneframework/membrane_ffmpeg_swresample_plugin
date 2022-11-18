defmodule Membrane.FFmpeg.SWResample.PipelineTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  alias Membrane.FFmpeg.SWResample.Converter
  alias Membrane.{RawAudio, Testing}

  @tag :tmp_dir
  test "surrounded by testing source and sink", %{tmp_dir: tmp_dir} do
    input_stream_format = %RawAudio{sample_format: :u8, sample_rate: 8_000, channels: 1}
    output_stream_format = %RawAudio{sample_format: :s16le, sample_rate: 16_000, channels: 2}
    frames = 8_000

    input_time = RawAudio.frames_to_time(frames, input_stream_format)
    fixture_path = Path.expand(Path.join(__DIR__, "/../fixtures/input_u8_mono_8khz.raw"))

    output_path = Path.expand(Path.join(tmp_dir, "output_s16le_stereo_16khz.raw"))

    structure = [
      child(:source, %Membrane.File.Source{location: fixture_path}),
      get_child(:source)
      |> child(:resampler, %Converter{
        input_stream_format: input_stream_format,
        output_stream_format: output_stream_format
      })
      |> child(:sink, %Membrane.File.Sink{location: output_path})
    ]

    assert {:ok, _pipeline_supervisor, pipeline} =
             Testing.Pipeline.start_link(structure: structure)

    assert_pipeline_setup(pipeline)
    assert_end_of_stream(pipeline, :sink)
    Testing.Pipeline.terminate(pipeline, blocking?: true)

    assert result = File.read!(output_path)
    assert byte_size(result) == RawAudio.time_to_bytes(input_time, output_stream_format)
  end
end
