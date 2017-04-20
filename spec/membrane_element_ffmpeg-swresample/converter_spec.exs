defmodule Membrane.Element.FFmpeg.SWResample.ConverterSpec do
  use ESpec, asyn: true
  alias Membrane.Element.FFmpeg.SWResample.ConverterNative
  alias Membrane.Buffer

  let :caps, do: Nil
  let :state, do: %{native: native()}

  describe ".handle_caps/3" do
    let :native, do: Nil
    it "should initialize native handle with receied caps" do
      expect(described_module().handle_caps :sink, caps(), state()).to eq {:ok, [{:caps, {:source, caps()}}], %{state() | native: <<>>}}
    end
  end

  defp mult_binary binary, count do
    0..count |> Enum.drop(1) |> Enum.map(fn _ -> binary end) |> IO.iodata_to_binary
  end

  describe ".handle_buffer/4" do
    let :buffer, do: %Buffer{payload: payload()}
    let! :native do
      {:ok, native} = ConverterNative.create
      native
    end

    describe "in usual case" do
      let :payload, do: <<1,2,3,4,5,6,7,8,8,7,6,5,4,3,2,1>> |> mult_binary(20)
      it "should convert data properly" do
        {:ok, [{:send, {:source, %Buffer{payload: result}}}], state} = described_module().handle_buffer :sink, caps(), buffer(), state()
        expect(state).to eq state()
        expect(byte_size result).to be :<=, 4*20
        expect(:binary.bin_to_list result).to have_all & &1 > 125 && &1 < 140
      end
    end

    describe "if data size is too small to process" do
      let :payload, do: Nil
      describe "if data is empty" do
        let :payload, do: <<>>
        it "should return ok result and not send anything forwards" do
          expect(described_module().handle_buffer :sink, caps(), buffer(), state()).to eq {:ok, state()}
        end
      end
      describe "if data is non-empty" do
        let :payload, do: <<1,2,3,4>>
        it "should return ok result and not send anything forwards" do
          expect(described_module().handle_buffer :sink, caps(), buffer(), state()).to eq {:ok, state()}
        end
      end
      it "should store data in internal buffer and convert it once size becomes big enough" do
        buffer = %Buffer{buffer() | payload: <<255, 127, 255, 127>>}
        expect(described_module().handle_buffer :sink, caps(), buffer, state()).to eq {:ok, state()}
        buffer = %Buffer{buffer() | payload: <<0, 0, 0, 0>> |> mult_binary(100)}
        {:ok, [{:send, {:source, %Buffer{payload: <<first_sample>> <> _}}}], _state}
          = described_module().handle_buffer :sink, caps(), buffer, state()
        expect(first_sample).to be :>, 160
      end
    end
  end

end
