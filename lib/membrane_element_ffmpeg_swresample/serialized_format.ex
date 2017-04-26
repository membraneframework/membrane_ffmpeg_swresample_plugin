defmodule Membrane.Element.FFmpeg.SWResample.SerializedFormat do
  use Bitwise

  @unsigned_sample_type 0b00 <<< 30
  @signed_sample_type 0b01 <<< 30
  @float_sample_type 0b11 <<< 30

  @le_sample_endianity 0b0 <<< 29
  @be_sample_endianity 0b1 <<< 29

  @sample_size (0b1 <<< 8) - 1

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
              "u" -> @unsigned_sample_type
              "s" -> @signed_sample_type
              "f" -> @float_sample_type
            end,
            String.to_integer(size),
            case endianity do
              "be" -> @be_sample_endianity
              _ -> @le_sample_endianity
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
    (serialized_format &&& @sample_size) / 8 |> Float.ceil |> trunc
  end

end
