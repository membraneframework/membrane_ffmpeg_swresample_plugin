defmodule Membrane.Element.FFmpeg.SWResample.SerializedFormat do
  use Bitwise

  defp unsigned_type, do: 0b00 <<< 30
  defp signed_type, do: 0b01 <<< 30
  defp float_type, do: 0b11 <<< 30

  defp le_endianity, do: 0b0 <<< 29
  defp be_endianity, do: 0b1 <<< 29

  defp size, do: (0b1 <<< 8) - 1

  @doc """
  converts audio format to 32-bit integer consisting of (from oldest bit):
    first 2 bits for type
    then 1 bit for endianity
    then sequence of zeroes
    last 8 bits for size (in bits)
  expects atom format
  returns format encoded as integer
  """
  def from_atom(format) do
    format \
      |> Atom.to_string \
      |> fn(format_str) -> Regex.split(~r/\d+/, format_str, include_captures: true) end.() \
      |> case do
          [type, size, endianity] -> [
            case type do
              "u" -> unsigned_type
              "s" -> signed_type
              "f" -> float_type
            end,
            String.to_integer(size),
            case endianity do
              "be" -> be_endianity
              _ -> le_endianity
            end
          ]
        end
      |> Enum.reduce(&bor/2)
  end

  @doc """
  expects serialized format
  returns sample size in bytes as integer
  """
  def sample_size(serialized_format) do
    (serialized_format &&& size) / 8 |> Float.ceil |> trunc
  end

end
