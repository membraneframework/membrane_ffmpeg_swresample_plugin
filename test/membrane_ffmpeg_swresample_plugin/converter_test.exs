defmodule Membrane.FFmpeg.SWResample.ConverterTest do
  use ExUnit.Case, async: true
  use Mockery
  alias Membrane.RawAudio
  alias Membrane.FFmpeg.SWResample.Converter

  @module Converter
  @native Converter.Native

  @s16le_format %RawAudio{
    channels: 2,
    sample_format: :s16le,
    sample_rate: 48_000
  }

  @u8_format %RawAudio{
    channels: 1,
    sample_format: :u8,
    sample_rate: 44_100
  }

  defp initial_state(_ctx) do
    %{
      state: %{
        input_stream_format: nil,
        input_stream_format_provided?: false,
        output_stream_format: @u8_format,
        frames_per_buffer: 2048,
        native: nil,
        queue: <<>>,
        pts_queue: [],
        last_valid_pts: nil
      }
    }
  end

  defp test_handle_stream_format(state) do
    Mockery.History.enable_history()
    mock(@native, [create: 6], {:ok, :mock_handle})
    mock(@native, [convert: 2], {:ok, <<>>})

    assert {actions, new_state} = @module.handle_stream_format(:input, @s16le_format, nil, state)

    assert actions == [stream_format: {:output, state.output_stream_format}]

    assert %{native: :mock_handle} = new_state

    input_fmt = @s16le_format.sample_format |> RawAudio.SampleFormat.serialize()
    input_rate = @s16le_format.sample_rate
    input_channel = @s16le_format.channels
    out_fmt = @u8_format.sample_format |> RawAudio.SampleFormat.serialize()
    out_rate = @u8_format.sample_rate
    out_channel = @u8_format.channels

    assert_called(
      @native,
      :create,
      [^input_fmt, ^input_rate, ^input_channel, ^out_fmt, ^out_rate, ^out_channel],
      1
    )
  end

  setup_all :initial_state

  describe "handle_setup/2" do
    test "should do nothing if input stream format is not set", %{state: state} do
      assert @module.handle_setup(nil, state) == {[], state}
      refute_called(@native, :create)
    end

    test "create native converter if stream format is set", %{state: initial_state} do
      state = %{
        initial_state
        | input_stream_format: @s16le_format,
          input_stream_format_provided?: true
      }

      Mockery.History.enable_history()
      mock(@native, [create: 6], {:ok, :mock_handle})

      assert {[], new_state} = @module.handle_setup(:stopped, state)

      assert %{native: :mock_handle} = new_state

      input_fmt = @s16le_format.sample_format |> RawAudio.SampleFormat.serialize()
      input_rate = @s16le_format.sample_rate
      input_channel = @s16le_format.channels
      out_fmt = @u8_format.sample_format |> RawAudio.SampleFormat.serialize()
      out_rate = @u8_format.sample_rate
      out_channel = @u8_format.channels

      assert_called(
        @native,
        :create,
        [^input_fmt, ^input_rate, ^input_channel, ^out_fmt, ^out_rate, ^out_channel],
        1
      )
    end

    test "if native cannot be created returns an error with reason and untouched state", %{
      state: initial_state
    } do
      state = %{
        initial_state
        | input_stream_format: @s16le_format,
          input_stream_format_provided?: true
      }

      mock(@native, [create: 6], {:error, :reason})

      assert_raise RuntimeError, fn -> @module.handle_setup(nil, state) end
    end
  end

  describe "handle_stream_format/4" do
    test "given new stream format when input_stream_format were not set should create native resource and store it in state",
         %{state: state} do
      test_handle_stream_format(state)
    end

    test "given the same stream format as set in options should create native resource and store it in state",
         %{state: initial_state} do
      state = %{initial_state | input_stream_format: @s16le_format}
      test_handle_stream_format(state)
    end

    test "should raise when received stream format don't match stream format input_stream_format set in options",
         %{
           state: initial_state
         } do
      state = %{
        initial_state
        | input_stream_format: @s16le_format,
          input_stream_format_provided?: true
      }

      assert_raise RuntimeError, fn ->
        @module.handle_stream_format(:input, @u8_format, nil, state)
      end
    end

    test "if native cannot be created returns an error with reason and untouched state", %{
      state: state
    } do
      mock(@native, [create: 6], {:error, :reason})
      mock(@native, [convert: 2], {:ok, <<>>})

      assert_raise RuntimeError, fn ->
        @module.handle_stream_format(:input, @s16le_format, nil, state)
      end
    end
  end

  describe "handle_buffer/4 should" do
    test "store payload in queue until there are at least 2 frames", %{state: initial_state} do
      state = %{initial_state | native: :mock_handle, input_stream_format: @s16le_format}
      payload = <<0::3*8>>
      buffer = %Membrane.Buffer{payload: payload}
      mock(@native, [convert: 2], {:error, :reason})

      assert {[], new_state} = @module.handle_buffer(:input, buffer, nil, state)

      assert %{new_state | pts_queue: nil} == %{state | queue: payload, pts_queue: nil}
      refute_called(@native, :convert)
    end

    test "convert full frames and leave the remainder in queue", %{state: initial_state} do
      state = %{
        initial_state
        | queue: <<250, 250, 0>>,
          native: :mock_handle,
          input_stream_format: @s16le_format
      }

      payload = <<0::7*8>>
      buffer = %Membrane.Buffer{payload: payload}
      result = <<250, 0, 0, 0>>
      mock(@native, [convert: 2], {:ok, result})

      assert {actions, new_state} = @module.handle_buffer(:input, buffer, nil, state)

      assert actions == [buffer: {:output, %Membrane.Buffer{payload: result}}]
      assert new_state == %{state | queue: <<0::2*8>>, pts_queue: [{nil, 308_700}]}
    end
  end
end
