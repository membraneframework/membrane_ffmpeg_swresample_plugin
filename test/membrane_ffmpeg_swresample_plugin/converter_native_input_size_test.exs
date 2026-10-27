defmodule Membrane.FFmpeg.SWResample.Converter.NativeInputSizeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Membrane.RawAudio

  @module Membrane.FFmpeg.SWResample.Converter.Native

  defp create(input_format, input_channels) do
    @module.create(
      RawAudio.SampleFormat.serialize(input_format),
      48_000,
      input_channels,
      RawAudio.SampleFormat.serialize(:s16le),
      48_000,
      1
    )
  end

  test "convert rejects input that is not a whole number of frames" do
    assert {:ok, state} = create(:s16le, 2)
    assert {:error, :invalid_input_size} = @module.convert(<<0::8*7>>, state)
    assert {:ok, _output} = @module.convert(<<0::8*8>>, state)
  end

  test "convert rejects s24le input that is not a whole number of frames" do
    assert {:ok, state} = create(:s24le, 2)
    assert {:error, :invalid_input_size} = @module.convert(<<0::8*9>>, state)
    assert {:ok, _output} = @module.convert(<<0::8*12>>, state)
  end
end
