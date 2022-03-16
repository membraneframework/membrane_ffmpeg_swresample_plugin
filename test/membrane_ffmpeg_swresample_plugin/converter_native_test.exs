defmodule Membrane.FFmpeg.SWResample.Converter.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Caps.Audio.Raw

  @module Membrane.FFmpeg.SWResample.Converter.Native

  defp valid_inputs(_ctx) do
    formats = [:u8, :s16le, :s32le, :f32le, :f64le]
    rates = [44_100, 48_000]
    channels = [1, 2]

    inputs =
      for input_fmt <- [:s24le | formats],
          input_rate <- rates,
          input_channels <- channels,
          out_fmt <- formats,
          out_rate <- rates,
          out_channels <- channels do
        [
          input_fmt |> Raw.Format.serialize(),
          input_rate,
          input_channels,
          out_fmt |> Raw.Format.serialize(),
          out_rate,
          out_channels
        ]
      end

    [valid_inputs: inputs]
  end

  defp serialize_input(input) do
    [
      input_fmt,
      input_rate,
      input_channels,
      out_fmt,
      out_rate,
      out_channels
    ] = input

    [
      input_fmt |> Raw.Format.serialize(),
      input_rate,
      input_channels,
      out_fmt |> Raw.Format.serialize(),
      out_rate,
      out_channels
    ]
  end

  defp mk_simple_converter(out_fmt, dst_fmt) do
    @module.create(
      out_fmt |> Raw.Format.serialize(),
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
      assert reason == :unsupported_dst_format

      input = [:s32be, 44_100, 2, :u8, 48_000, 2] |> serialize_input()
      assert {:error, reason} = apply(@module, :create, input)
      assert reason == :unsupported_src_format
    end

    test "return proper error when number of channels is not supported" do
      input = [:s32le, 48_000, 4, :s16le, 48_000, 2] |> serialize_input()
      assert {:error, reason} = apply(@module, :create, input)
      assert reason == :unsupported_src_channels_no

      input = [:s32le, 48_000, 2, :s16le, 48_000, 4] |> serialize_input()
      assert {:error, reason} = apply(@module, :create, input)
      assert reason == :unsupported_dst_channels_no
    end
  end

  describe "convert/2 should" do
    test "return an empty binary for empty input" do
      {:ok, handle} = mk_simple_converter(:s16le, :u8)
      assert @module.convert(<<>>, handle) == {:ok, <<>>}
    end

    test "convert s16le samples to u8" do
      {:ok, handle} = mk_simple_converter(:s16le, :u8)
      # convert 8 s16le samples
      assert {:ok, <<result::binary>>} = @module.convert(<<0::128>>, handle)
      # make sure nothing has been buffored
      assert @module.convert(<<>>, handle) == {:ok, <<>>}
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
      assert {:ok, <<result::binary>>} = @module.convert(<<0::192>>, handle)
      # make sure nothing has been buffored
      assert @module.convert(<<>>, handle) == {:ok, <<>>}
      assert byte_size(result) == 16

      result
      |> :erlang.binary_to_list()
      |> Enum.each(fn sample ->
        # using in_delta because of dithering (which is random) applied to samples
        assert_in_delta sample, 0, 2
      end)
    end

    test "reduce samples size 8 times for s16le @ 48000 Hz -> u8 @ 24000 Hz conversion" do
      for size <- [1234, 5120, 20_480, 384_000] do
        {:ok, handle} =
          @module.create(
            :s16le |> Raw.Format.serialize(),
            48_000,
            2,
            :u8 |> Raw.Format.serialize(),
            24_000,
            1
          )

        input = for _i <- 1..size, do: <<:rand.uniform(255)>>, into: <<>>
        assert {:ok, res_head} = @module.convert(input, handle)
        assert {:ok, res_tail} = @module.convert(<<>>, handle)
        result = res_head <> res_tail
        assert round(byte_size(input) / 8) == byte_size(result)
      end
    end

    test "reduce samples size approprietly for f32le @ 48000 Hz -> s16le @ 441000 Hz conversion" do
      for n <- [1, 10, 100] do
        {:ok, handle} =
          @module.create(
            :f32le |> Raw.Format.serialize(),
            48_000,
            2,
            :s16le |> Raw.Format.serialize(),
            44_100,
            2
          )

        # 2 channels, n * 480 samples per channel, 32 bits (4 bytes) each
        input = for _i <- 1..(2 * n * 480), do: <<:rand.uniform()::size(32)-float>>, into: <<>>
        assert byte_size(input) == 2 * n * 480 * 4

        assert {:ok, res_head} = @module.convert(input, handle)
        assert {:ok, res_tail} = @module.convert(<<>>, handle)

        result = res_head <> res_tail
        # 2 channels, n * 441 samples per channel, 16 bits (2 bytes) each
        assert byte_size(result) == 2 * n * 441 * 2
      end
    end
  end
end
