defmodule Membrane.Element.FFmpeg.SWResample.Converter do
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.Raw, as: Caps
  alias Membrane.Element.FFmpeg.SWResample.ConverterNative

  def_known_source_pads %{
    :sink => {:always, [
      %Caps{format: :f64le},
      %Caps{format: :f32le},
      %Caps{format: :s32le},
      %Caps{format: :u32le},
      %Caps{format: :s16le},
      %Caps{format: :u16le},
      %Caps{format: :s8},
      %Caps{format: :u8},
    ]}
  }

  def_known_sink_pads %{
    :source => {:always, [
      %Caps{format: :f64le},
      %Caps{format: :f32le},
      %Caps{format: :s32le},
      %Caps{format: :u32le},
      %Caps{format: :s16le},
      %Caps{format: :u16le},
      %Caps{format: :s8},
      %Caps{format: :u8},
    ]}
  }
  #TODO: add passing target caps as argument
  def handle_init _ do
    {:ok, %{native: nil}}
  end

  def handle_caps :sink, caps, state do
    #TODO: pass new caps to native
    case ConverterNative.create do
      {:ok, native} -> {:ok, [{:caps, {:source, caps}}], %{state | native: native}}
      {:error, reason} -> {:error, reason, state}
    end
  end

  def handle_buffer :sink, _caps, %Membrane.Buffer{}, %{native: nil} do
    {:error, "FFmpeg swresample: native uninitialized, initialzation has failed or received no/invalid caps"}
  end
  def handle_buffer :sink, _caps, %Membrane.Buffer{payload: payload} = buffer, %{native: native} = state do
    case ConverterNative.convert native, payload do
      {:ok, <<>>} -> {:ok, state}
      {:ok, result} -> {:ok, [{:send, {:source, %Membrane.Buffer{buffer | payload: result}}}], state}
      {:error, desc} -> {:error, desc}
    end
  end

end
