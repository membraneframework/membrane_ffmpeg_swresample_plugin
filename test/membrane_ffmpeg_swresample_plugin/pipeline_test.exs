defmodule Membrane.FFmpeg.SWResample.PipelineTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions

  alias Membrane.{Testing, RawAudio}
  alias Membrane.FFmpeg.SWResample.Converter

  @tag :tmp_dir
  test "surrounded by testing source and sink", %{tmp_dir: tmp_dir} do
    input_caps = %RawAudio{sample_format: :u8, sample_rate: 8_000, channels: 1}
    output_caps = %RawAudio{sample_format: :s16le, sample_rate: 16_000, channels: 2}
    frames = 8_000

    input_time = RawAudio.frames_to_time(frames, input_caps)
    fixture_path = Path.expand(Path.join(__DIR__, "/../fixtures/input_u8_mono_8khz.raw"))

    output_path = Path.expand(Path.join(tmp_dir, "output_s16le_stereo_16khz.raw"))

    children = [
      source: %Membrane.File.Source{location: fixture_path},
      resampler: %Converter{input_caps: input_caps, output_caps: output_caps},
      sink: %Membrane.File.Sink{location: output_path}
    ]

    opts = [
      links: Membrane.ParentSpec.link_linear(children)
    ]

    assert {:ok, pipeline} = Testing.Pipeline.start_link(opts)
    Testing.Pipeline.play(pipeline)
    assert_pipeline_playback_changed(pipeline, :prepared, :playing)
    assert_end_of_stream(pipeline, :sink)
    Testing.Pipeline.stop_and_terminate(pipeline, blocking?: true)

    assert result = File.read!(output_path)
    assert byte_size(result) == RawAudio.time_to_bytes(input_time, output_caps)
  end
end
