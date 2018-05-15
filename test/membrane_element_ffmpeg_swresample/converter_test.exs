defmodule Membrane.Element.FFmpeg.SWResample.ConverterTest do
  use ExUnit.Case, async: true
  use Mockery
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Element.FFmpeg.SWResample.Converter

  @module Converter
  @native Converter.Native

  @s16le_caps %Raw{
    channels: 2,
    format: :s16le,
    sample_rate: 48_000
  }

  @u8_caps %Raw{
    channels: 1,
    format: :u8,
    sample_rate: 44_100
  }

  def initial_state(_) do
    %{
      state: %{
        sink_caps: nil,
        source_caps: @u8_caps,
        frames_per_buffer: 2048,
        native: nil,
        queue: <<>>
      }
    }
  end

  def test_handle_caps(state) do
    Mockery.History.enable_history()
    mock(@native, [create: 6], {:ok, :mock_handle})

    assert {{:ok, commands}, new_state} = @module.handle_caps(:sink, @s16le_caps, nil, state)
    assert length(commands) == 2
    assert {:source, state.source_caps} == commands[:caps]
    assert :source == commands[:redemand]

    assert %{native: :mock_handle} = new_state

    sink_fmt = @s16le_caps.format |> Raw.Format.serialize()
    sink_rate = @s16le_caps.sample_rate
    sink_channel = @s16le_caps.channels
    src_fmt = @u8_caps.format |> Raw.Format.serialize()
    src_rate = @u8_caps.sample_rate
    src_channel = @u8_caps.channels

    assert_called(
      @native,
      :create,
      [^sink_fmt, ^sink_rate, ^sink_channel, ^src_fmt, ^src_rate, ^src_channel],
      1
    )
  end

  setup_all :initial_state

  describe "handle_prepare/2" do
    test "should do nothing if sink caps are not set", %{state: state} do
      assert @module.handle_prepare(:stopped, state) == {:ok, state}
      assert @module.handle_prepare(:prepared, state) == {:ok, state}
      assert @module.handle_prepare(:playing, state) == {:ok, state}
      refute_called(@native, :create)
    end

    test "create native converter if caps are set", %{state: initial_state} do
      state = %{initial_state | sink_caps: @s16le_caps}
      Mockery.History.enable_history()
      mock(@native, [create: 6], {:ok, :mock_handle})

      assert {{:ok, commands}, new_state} = @module.handle_prepare(:stopped, state)
      assert length(commands) == 1
      assert {:source, state.source_caps} == commands[:caps]

      assert %{native: :mock_handle} = new_state

      sink_fmt = @s16le_caps.format |> Raw.Format.serialize()
      sink_rate = @s16le_caps.sample_rate
      sink_channel = @s16le_caps.channels
      src_fmt = @u8_caps.format |> Raw.Format.serialize()
      src_rate = @u8_caps.sample_rate
      src_channel = @u8_caps.channels

      assert_called(
        @native,
        :create,
        [^sink_fmt, ^sink_rate, ^sink_channel, ^src_fmt, ^src_rate, ^src_channel],
        1
      )
    end

    test "if native cannot be created returns an error with reason and untouched state", %{
      state: initial_state
    } do
      state = %{initial_state | sink_caps: @s16le_caps}
      mock(@native, [create: 6], {:error, :reason})
      assert @module.handle_prepare(:stopped, state) == {{:error, :reason}, state}
    end
  end

  describe "handle_caps/4" do
    test "given new caps when sink_caps were not set should create native resource and store it in state",
         %{state: state} do
      test_handle_caps(state)
    end

    test "given the same caps as set in options should create native resource and store it in state",
         %{state: initial_state} do
      state = %{initial_state | sink_caps: @s16le_caps}
      test_handle_caps(state)
    end

    test "should raise when received caps don't match caps sink_caps set in options", %{
      state: initial_state
    } do
      state = %{initial_state | sink_caps: @s16le_caps}

      assert_raise RuntimeError, fn ->
        @module.handle_caps(:sink, @u8_caps, nil, state)
      end
    end

    test "if native cannot be created returns an error with reason and untouched state", %{
      state: state
    } do
      mock(@native, [create: 6], {:error, :reason})
      assert @module.handle_caps(:sink, @s16le_caps, nil, state) == {{:error, :reason}, state}
    end
  end

  describe "handle_demand/4 should" do
    test "pass the demand if converter have been created and demand was in bytes", %{
      state: initial_state
    } do
      state = %{initial_state | native: :not_nil}
      assert {{:ok, commands}, ^state} = @module.handle_demand(:source, 42, :bytes, nil, state)
      assert commands == [demand: {:sink, 42}]
    end

    test "calculate and pass proper demand in bytes if converter have been created and demand was in buffers",
         %{state: initial_state} do
      state = %{initial_state | native: :not_nil, sink_caps: @s16le_caps}
      assert {{:ok, commands}, ^state} = @module.handle_demand(:source, 2, :buffers, nil, state)

      buffers_size =
        2 * state.frames_per_buffer * Raw.sample_size(state.sink_caps) * state.sink_caps.channels

      assert commands == [demand: {:sink, buffers_size}]
    end

    test "ignore the demands if converter haven't been created", %{state: state} do
      assert @module.handle_demand(:source, 42, :bytes, nil, state) == {:ok, state}
    end
  end

  describe "handle_process1/4 should" do
    test "store payload in queue until there are at least 2 frames", %{state: initial_state} do
      state = %{initial_state | native: :mock_handle}
      payload = <<0::3*8>>
      buffer = %Membrane.Buffer{payload: payload}
      mock(@native, [convert: 2], {:error, :reason})

      assert {:ok, new_state} =
               @module.handle_process1(:sink, buffer, %{caps: @s16le_caps}, state)

      assert new_state == %{state | queue: payload}
      refute_called(@native, :convert)
    end

    test "convert full frames and leave the remainder in queue", %{state: initial_state} do
      state = %{initial_state | queue: <<250, 250, 0>>, native: :mock_handle}
      payload = <<0::7*8>>
      buffer = %Membrane.Buffer{payload: payload}
      result = <<250, 0, 0, 0>>
      mock(@native, [convert: 2], {:ok, result})

      assert {{:ok, commands}, new_state} =
               @module.handle_process1(:sink, buffer, %{caps: @s16le_caps}, state)

      assert commands == [buffer: {:source, %Membrane.Buffer{payload: result}}]
      assert new_state == %{state | queue: <<0::2*8>>}
    end
  end
end
