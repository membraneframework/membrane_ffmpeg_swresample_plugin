defmodule Membrane.Element.FFmpeg.SWResample.Converter.Options do
  @moduledoc """
  Options passed to converter. If sink_caps field equals nil, those caps are
  assumed to be received through :sink.
  """

  @enforce_keys [:source_caps]
  defstruct \
    sink_caps: nil,
    source_caps: nil

end
