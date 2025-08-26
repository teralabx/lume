defmodule Lume.Provider do
  @moduledoc """
  Behaviour for AI provider implementations.
  Supports both synchronous calls and streaming responses.
  """

  @type execution_mode :: :sync | :stream
  @type response_format :: :text | :json | :structured

  @doc """
  Build the request payload for the specific provider.
  Each provider formats requests differently (OpenAI vs Gemini vs Claude).
  """
  @callback build_request(lume :: Lume.t()) :: map()

  @doc """
  Execute a synchronous call to the AI provider.
  Returns updated Lume struct with response, cost, and token usage.
  """
  @callback call(lume :: Lume.t()) :: {:ok, Lume.t()} | {:error, any()}

  @doc """
  Execute a streaming call to the AI provider.
  Returns a Stream that yields chunks as they arrive.
  """
  @callback stream(lume :: Lume.t()) :: {:ok, Stream.t()} | {:error, any()}

  @optional_callbacks [stream: 1]
end
