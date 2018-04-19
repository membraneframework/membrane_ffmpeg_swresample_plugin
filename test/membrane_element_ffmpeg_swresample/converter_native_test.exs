defmodule Membrane.Element.FFmpeg.SWResample.Converter.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Caps.Audio.Raw

  @module Membrane.Element.FFmpeg.SWResample.Converter.Native

  def valid_inputs(_) do
    formats = [:u8, :s16le, :s32le, :f32le, :f64le]
    rates = [44_100, 48_000]
    channels = [1, 2]

    inputs =
      for sink_fmt <- [:s24le | formats],
          sink_rate <- rates,
          sink_channels <- channels,
          src_fmt <- formats,
          src_rate <- rates,
          src_channels <- channels do
        [
          sink_fmt |> Raw.Format.serialize(),
          sink_rate,
          sink_channels,
          src_fmt |> Raw.Format.serialize(),
          src_rate,
          src_channels
        ]
      end

    [valid_inputs: inputs]
  end

  def serialize_input(input) do
    [
      sink_fmt,
      sink_rate,
      sink_channels,
      src_fmt,
      src_rate,
      src_channels
    ] = input

    [
      sink_fmt |> Raw.Format.serialize(),
      sink_rate,
      sink_channels,
      src_fmt |> Raw.Format.serialize(),
      src_rate,
      src_channels
    ]
  end

  def mk_simple_converter(src_fmt, dst_fmt) do
    @module.create(
      src_fmt |> Raw.Format.serialize(),
      48_000,
      1,
      dst_fmt |> Raw.Format.serialize(),
      48_000,
      1
    )
  end

  describe "create/6 should" do
    setup :valid_inputs

    test "return native resource when conversion is supported", %{valid_inputs: inputs} do
      inputs
      |> Enum.each(fn input ->
        assert {:ok, native_handle} = apply(@module, :create, input)
        assert is_reference(native_handle)
      end)
    end

    test "return proper error when format is not supported" do
      input = [:s32le, 44_100, 2, :s24le, 48_000, 2] |> serialize_input()
      assert {:error, reason} = apply(@module, :create, input)
      assert reason == {:args, :dst_format, 'Unsupported sample format'}

      input = [:s32be, 44_100, 2, :u8, 48_000, 2] |> serialize_input()
      assert {:error, reason} = apply(@module, :create, input)
      assert reason == {:args, :src_format, 'Unsupported sample format'}
    end

    test "return proper error when number of channels is not supported" do
      input = [:s32le, 48_000, 4, :s16le, 48_000, 2] |> serialize_input()
      assert {:error, reason} = apply(@module, :create, input)
      assert reason == {:args, :src_channels, 'Unsupported number of channels'}

      input = [:s32le, 48_000, 2, :s16le, 48_000, 4] |> serialize_input()
      assert {:error, reason} = apply(@module, :create, input)
      assert reason == {:args, :dst_channels, 'Unsupported number of channels'}
    end
  end

  describe "convert/2 should" do
    test "return an empty binary for empty input" do
      {:ok, handle} = mk_simple_converter(:s16le, :u8)
      assert @module.convert(handle, <<>>) == {:ok, <<>>}
    end

    test "convert s16le samples to u8" do
      {:ok, handle} = mk_simple_converter(:s16le, :u8)
      # convert 8 s16le samples
      assert {:ok, <<result::binary>>} = @module.convert(handle, <<0::128>>)
      assert byte_size(result) == 8

      result
      |> :erlang.binary_to_list()
      |> Enum.each(fn sample ->
        # using in_delta because of dithering (which is random) applied to samples
        assert_in_delta sample, 128, 2
      end)
    end

    test "convert s24le samples to s16le" do
      {:ok, handle} = mk_simple_converter(:s24le, :s16le)
      # convert 8 s24le samples
      assert {:ok, <<result::binary>>} = @module.convert(handle, <<0::192>>)
      assert byte_size(result) == 16

      result
      |> :erlang.binary_to_list()
      |> Enum.each(fn sample ->
        # using in_delta because of dithering (which is random) applied to samples
        assert_in_delta sample, 0, 2
      end)
    end
  end
end
