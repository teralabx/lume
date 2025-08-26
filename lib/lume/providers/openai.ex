defmodule Lume.Providers.OpenAI do
  @moduledoc """
  OpenAI provider implementation supporting GPT-4o, GPT-4o-mini, o1 series models.
  Supports text, vision, streaming, structured outputs with JSON schema.
  """

  @behaviour Lume.Provider

  @base_url "https://api.openai.com/v1"
  @models %{
    "gpt-4o" => %{pricing: %{input: 0.0025, output: 0.01}, vision: true},
    "gpt-4o-mini" => %{pricing: %{input: 0.00015, output: 0.0006}, vision: true},
    "gpt-4-turbo" => %{pricing: %{input: 0.01, output: 0.03}, vision: true},
    "o1-preview" => %{pricing: %{input: 0.075, output: 0.15}, vision: false},
    "o1-mini" => %{pricing: %{input: 0.018, output: 0.072}, vision: false}
  }

  @impl true
  def build_request(%Lume{} = lume) do
    messages = build_messages(lume)

    base_request = %{
      model: lume.model || "gpt-4o",
      messages: messages
    }

    base_request
    |> maybe_add_streaming(lume.opts)
    |> maybe_add_structured_output(lume.opts)
    |> maybe_add_temperature(lume.opts)
  end

  @impl true
  def call(%Lume{} = lume) do
    with {:ok, api_key} <- get_api_key(),
         request <- build_request(lume),
         {:ok, %{status: 200, body: response}} <-
           make_request("/chat/completions", request, api_key) do
      content = get_in(response, ["choices", Access.at(0), "message", "content"])
      usage = response["usage"]

      cost = calculate_cost(lume.model || "gpt-4o", usage)
      tokens = usage["total_tokens"] || 0

      updated_lume = %{
        lume
        | last_result: content,
          cost: lume.cost + cost,
          tokens_used: lume.tokens_used + tokens
      }

      {:ok, updated_lume}
    else
      {:error, reason} -> {:error, reason}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
    end
  end

  @impl true
  def stream(%Lume{} = lume) do
    with {:ok, api_key} <- get_api_key(),
         request <- build_request(Map.put(lume, :opts, Keyword.put(lume.opts, :stream, true))),
         {:ok, %{status: 200, body: body}} <-
           make_stream_request("/chat/completions", request, api_key) do
      stream =
        body
        |> Stream.map(&decode_sse_chunk/1)
        |> Stream.filter(&(&1 != nil))
        |> Stream.take_while(&(&1 != "[DONE]"))
        |> Stream.map(&extract_content_from_chunk/1)
        |> Stream.filter(&(&1 != nil))

      {:ok, stream}
    else
      {:error, reason} -> {:error, reason}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
    end
  end

  # Private functions

  defp build_messages(%Lume{messages: messages}) do
    Enum.map(messages, &convert_message_to_openai/1)
  end

  defp convert_message_to_openai(%{role: role, content: content}) do
    openai_role = case role do
      :system -> "system"
      :user -> "user"
      :assistant -> "assistant"
    end
    
    openai_content = case content do
      text when is_binary(text) ->
        text
      content_parts when is_list(content_parts) ->
        Enum.map(content_parts, &convert_content_part/1)
    end
    
    %{role: openai_role, content: openai_content}
  end

  defp convert_content_part(%{type: :text, content: text}) do
    %{type: "text", text: text}
  end

  defp convert_content_part(%{type: :image, content: image_data}) do
    %{
      type: "image_url",
      image_url: %{
        url: format_image_data(image_data)
      }
    }
  end

  defp convert_content_part(%{type: :audio}) do
    %{type: "text", text: "[Audio not yet supported]"}
  end

  defp convert_content_part(%{type: :file}) do
    %{type: "text", text: "[Files not yet supported]"}
  end

  defp format_image_data("data:" <> _ = data_url), do: data_url
  defp format_image_data(base64_data), do: "data:image/jpeg;base64,#{base64_data}"


  defp maybe_add_streaming(request, opts) do
    if Keyword.get(opts, :stream, false) do
      Map.put(request, :stream, true)
    else
      request
    end
  end

  defp maybe_add_structured_output(request, opts) do
    case Keyword.get(opts, :response_schema) do
      nil ->
        request

      schema ->
        Map.put(request, :response_format, %{
          type: "json_schema",
          json_schema: %{
            name: "response",
            strict: true,
            schema: schema
          }
        })
    end
  end

  defp maybe_add_temperature(request, opts) do
    case Keyword.get(opts, :temperature) do
      nil -> request
      temp -> Map.put(request, :temperature, temp)
    end
  end

  defp get_api_key do
    case Application.get_env(:lume, :openai_api_key) || System.get_env("OPENAI_API_KEY") do
      nil -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  end

  defp make_request(path, body, api_key) do
    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    Req.post("#{@base_url}#{path}", json: body, headers: headers)
  end

  defp make_stream_request(path, body, api_key) do
    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"},
      {"accept", "text/event-stream"}
    ]

    Req.post("#{@base_url}#{path}", json: body, headers: headers, into: :self)
  end

  defp decode_sse_chunk(chunk) do
    chunk
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      if String.starts_with?(line, "data: ") do
        data = String.slice(line, 6..-1//1)

        if data == "[DONE]" do
          "[DONE]"
        else
          case Jason.decode(data) do
            {:ok, parsed} -> parsed
            _ -> nil
          end
        end
      end
    end)
  end

  defp extract_content_from_chunk("[DONE]"), do: nil

  defp extract_content_from_chunk(chunk) when is_map(chunk) do
    get_in(chunk, ["choices", Access.at(0), "delta", "content"])
  end

  defp calculate_cost(model, usage) do
    pricing = get_in(@models, [model, :pricing]) || %{input: 0, output: 0}
    input_tokens = usage["prompt_tokens"] || 0
    output_tokens = usage["completion_tokens"] || 0

    input_tokens * pricing.input / 1000 + output_tokens * pricing.output / 1000
  end
end
