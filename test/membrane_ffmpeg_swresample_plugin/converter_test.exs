defmodule Membrane.FFmpeg.SWResample.ConverterTest do
  use ExUnit.Case, async: true
  use Mockery
  alias Membrane.RawAudio
  alias Membrane.FFmpeg.SWResample.Converter

  @module Converter
  @native Converter.Native

  @s16le_caps %RawAudio{
    channels: 2,
    sample_format: :s16le,
    sample_rate: 48_000
  }

  @u8_caps %RawAudio{
    channels: 1,
    sample_format: :u8,
    sample_rate: 44_100
  }

  defp initial_state(_ctx) do
    %{
      state: %{
        input_caps: nil,
        input_caps_provided?: false,
        output_caps: @u8_caps,
        frames_per_buffer: 2048,
        native: nil,
        queue: <<>>
      }
    }
  end

  defp test_handle_caps(state) do
    Mockery.History.enable_history()
    mock(@native, [create: 6], {:ok, :mock_handle})

    assert {{:ok, actions}, new_state} = @module.handle_caps(:input, @s16le_caps, nil, state)
    assert actions == [caps: {:output, state.output_caps}]

    assert %{native: :mock_handle} = new_state

    input_fmt = @s16le_caps.sample_format |> RawAudio.SampleFormat.serialize()
    input_rate = @s16le_caps.sample_rate
    input_channel = @s16le_caps.channels
    out_fmt = @u8_caps.sample_format |> RawAudio.SampleFormat.serialize()
    out_rate = @u8_caps.sample_rate
    out_channel = @u8_caps.channels

    assert_called(
      @native,
      :create,
      [^input_fmt, ^input_rate, ^input_channel, ^out_fmt, ^out_rate, ^out_channel],
      1
    )
  end

  setup_all :initial_state

  describe "handle_stopped_to_prepared/2" do
    test "should do nothing if input caps are not set", %{state: state} do
      assert @module.handle_stopped_to_prepared(nil, state) == {:ok, state}
      refute_called(@native, :create)
    end

    test "create native converter if caps are set", %{state: initial_state} do
      state = %{initial_state | input_caps: @s16le_caps, input_caps_provided?: true}
      Mockery.History.enable_history()
      mock(@native, [create: 6], {:ok, :mock_handle})

      assert {{:ok, actions}, new_state} = @module.handle_stopped_to_prepared(:stopped, state)

      assert length(actions) == 1
      assert {:output, state.output_caps} == actions[:caps]

      assert %{native: :mock_handle} = new_state

      input_fmt = @s16le_caps.sample_format |> RawAudio.SampleFormat.serialize()
      input_rate = @s16le_caps.sample_rate
      input_channel = @s16le_caps.channels
      out_fmt = @u8_caps.sample_format |> RawAudio.SampleFormat.serialize()
      out_rate = @u8_caps.sample_rate
      out_channel = @u8_caps.channels

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
      state = %{initial_state | input_caps: @s16le_caps, input_caps_provided?: true}
      mock(@native, [create: 6], {:error, :reason})

      assert @module.handle_stopped_to_prepared(:stopped, state) == {{:error, :reason}, state}
    end
  end

  describe "handle_caps/4" do
    test "given new caps when input_caps were not set should create native resource and store it in state",
         %{state: state} do
      test_handle_caps(state)
    end

    test "given the same caps as set in options should create native resource and store it in state",
         %{state: initial_state} do
      state = %{initial_state | input_caps: @s16le_caps}
      test_handle_caps(state)
    end

    test "should raise when received caps don't match caps input_caps set in options", %{
      state: initial_state
    } do
      state = %{initial_state | input_caps: @s16le_caps, input_caps_provided?: true}

      assert_raise RuntimeError, fn ->
        @module.handle_caps(:input, @u8_caps, nil, state)
      end
    end

    test "if native cannot be created returns an error with reason and untouched state", %{
      state: state
    } do
      mock(@native, [create: 6], {:error, :reason})
      assert @module.handle_caps(:input, @s16le_caps, nil, state) == {{:error, :reason}, state}
    end
  end

  describe "handle_process/4 should" do
    test "store payload in queue until there are at least 2 frames", %{state: initial_state} do
      state = %{initial_state | native: :mock_handle, input_caps: @s16le_caps}
      payload = <<0::3*8>>
      buffer = %Membrane.Buffer{payload: payload}
      mock(@native, [convert: 2], {:error, :reason})

      assert {:ok, new_state} = @module.handle_process(:input, buffer, nil, state)

      assert new_state == %{state | queue: payload}
      refute_called(@native, :convert)
    end

    test "convert full frames and leave the remainder in queue", %{state: initial_state} do
      state = %{
        initial_state
        | queue: <<250, 250, 0>>,
          native: :mock_handle,
          input_caps: @s16le_caps
      }

      payload = <<0::7*8>>
      buffer = %Membrane.Buffer{payload: payload}
      result = <<250, 0, 0, 0>>
      mock(@native, [convert: 2], {:ok, result})

      assert {{:ok, actions}, new_state} = @module.handle_process(:input, buffer, nil, state)

      assert actions == [buffer: {:output, %Membrane.Buffer{payload: result}}]
      assert new_state == %{state | queue: <<0::2*8>>}
    end
  end

  test "handle_prepared_to_stopped should remove native from state", %{state: initial_state} do
    state = %{initial_state | native: :mock_handle}
    assert {:ok, new_state} = @module.handle_prepared_to_stopped(nil, state)
    assert new_state == %{state | native: nil}
  end
end
