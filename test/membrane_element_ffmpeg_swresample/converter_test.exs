defmodule Membrane.Element.FFmpeg.SWResample.ConverterTest do
  use ExUnit.Case, async: true
  use Mockery
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Element.FFmpeg.SWResample.Converter

  @module Converter
  @native Converter.Native

  @s16le_caps %Raw{
    channels: 1,
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
        source_caps: nil,
        native: nil,
        queue: <<>>
      }
    }
  end

  def sink_s16le_caps(%{state: state}) do
    %{state: %{state | sink_caps: @s16le_caps}}
  end

  def src_u8_caps(%{state: state}) do
    %{state: %{state | source_caps: @u8_caps}}
  end

  setup_all :initial_state

  describe "handle_caps/4" do
    setup :src_u8_caps

    test "given new caps should create native resource and store it in state", %{state: state} do
      mock(@native, [create: 6], fn a, b, c, d, e, f ->
        send(self(), [a, b, c, d, e, f])
        {:ok, :mock_handle}
      end)

      assert {{:ok, commands}, new_state} = @module.handle_caps(:sink, @s16le_caps, nil, state)
      assert {:source, state.source_caps} == commands[:caps]
      assert :source == commands[:redemand]

      assert %{native: :mock_handle} = new_state

      expected_args = [
        @s16le_caps.format |> Raw.Format.serialize(),
        @s16le_caps.sample_rate,
        @s16le_caps.channels,
        @u8_caps.format |> Raw.Format.serialize(),
        @u8_caps.sample_rate,
        @u8_caps.channels
      ]

      assert_receive(^expected_args)
    end
  end
end
