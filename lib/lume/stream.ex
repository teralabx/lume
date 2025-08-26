defmodule Lume.Stream do
  @moduledoc """
  Stream parsing utilities for SSE responses.
  """

  @doc """
  Parse SSE chunk and extract JSON data.
  """
  def parse_sse_chunk(chunk) do
    chunk
    |> String.split("\n")
    |> Enum.find_value(&parse_line/1)
  end

  defp parse_line("data: " <> data), do: decode_json(data)
  defp parse_line(line) when line != "", do: decode_json(line)
  defp parse_line(_), do: nil

  defp decode_json("[DONE]"), do: "[DONE]"

  defp decode_json(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end
end
