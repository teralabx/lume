defmodule Lume.Providers.Gemini do
  @moduledoc """
  Google Gemini provider implementation supporting Gemini 2.5 Pro/Flash, 2.0 Flash models.
  Supports text, vision, streaming, structured outputs with response schema.
  """

  @behaviour Lume.Provider

  @base_url "https://generativelanguage.googleapis.com"
  @models %{
    "gemini-2.5-flash" => %{pricing: %{input: 0.00035, output: 0.00105}, vision: true},
    "gemini-2.5-pro" => %{pricing: %{input: 0.0011, output: 0.0011}, vision: true},
    "gemini-2.0-flash" => %{pricing: %{input: 0.00035, output: 0.00105}, vision: true},
    "gemini-1.5-pro" => %{pricing: %{input: 0.00125, output: 0.005}, vision: true},
    "gemini-1.5-flash" => %{pricing: %{input: 0.000075, output: 0.0003}, vision: true}
  }

  @impl true
  def build_request(%Lume{} = lume) do
    %{}
    |> build_contents(lume)
    |> add_system_instruction(lume)
    |> add_generation_config(lume)
    |> add_structured_output(lume)
    |> add_safety_settings(lume)
  end

  @impl true
  def call(%Lume{} = lume) do
    with {:ok, api_key} <- get_api_key(),
         model <- lume.model || "gemini-2.5-flash",
         request <- build_request(lume),
         {:ok, %{status: 200, body: response}} <-
           make_request(model, "generateContent", request, api_key, lume.opts) do
      content =
        get_in(response, ["candidates", Access.at(0), "content", "parts", Access.at(0), "text"])

      usage = response["usageMetadata"]

      cost = calculate_cost(model, usage)
      tokens = usage["totalTokenCount"] || 0

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
         model <- lume.model || "gemini-2.5-flash",
         request <- build_request(lume),
         {:ok, %{status: 200, body: body}} <-
           make_stream_request(model, "streamGenerateContent", request, api_key) do
      stream =
        body
        |> Stream.map(&Lume.Stream.parse_sse_chunk/1)
        |> Stream.filter(&(&1 != nil))
        |> Stream.map(&extract_content_from_chunk/1)
        |> Stream.filter(&(&1 != nil))

      {:ok, stream}
    else
      {:error, reason} -> {:error, reason}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
    end
  end

  # Private functions

  defp build_contents(request, %Lume{messages: messages} = lume) do
    contents = convert_messages_to_contents(messages, lume.model)
    Map.put(request, :contents, contents)
  end

  defp add_system_instruction(request, %Lume{messages: messages}) do
    case find_system_message(messages) do
      nil -> request
      system_content -> Map.put(request, :system_instruction, %{parts: [%{text: system_content}]})
    end
  end

  defp add_generation_config(request, %Lume{opts: opts}) do
    config = %{}

    config =
      case Keyword.get(opts, :temperature) do
        nil -> config
        temp -> Map.put(config, :temperature, temp)
      end

    config =
      case Keyword.get(opts, :max_tokens) do
        nil -> config
        max -> Map.put(config, :maxOutputTokens, max)
      end

    if config == %{} do
      request
    else
      Map.put(request, :generationConfig, config)
    end
  end

  defp add_structured_output(request, %Lume{opts: opts}) do
    case Keyword.get(opts, :response_schema) do
      nil ->
        request

      schema ->
        generation_config = Map.get(request, :generationConfig, %{})

        updated_config =
          generation_config
          |> Map.put(:responseMimeType, "application/json")
          |> Map.put(:responseSchema, schema)

        Map.put(request, :generationConfig, updated_config)
    end
  end

  defp add_safety_settings(request, %Lume{opts: opts}) do
    case Keyword.get(opts, :safety_settings) do
      nil -> request
      settings -> Map.put(request, :safetySettings, settings)
    end
  end

  defp find_system_message(messages) do
    case Enum.find(messages, &(&1.role == :system)) do
      %{content: content} -> content
      nil -> nil
    end
  end

  defp get_role(:assistant), do: "model"
  defp get_role(_), do: "user"

  defp convert_messages_to_contents(messages, model) do
    messages
    |> Enum.filter(&(&1.role != :system))
    |> Enum.map(&convert_message_to_content(&1, model))
  end

  defp convert_message_to_content(%{role: role, content: content}, model) do
    parts =
      case content do
        text when is_binary(text) ->
          [%{text: text}]

        content_parts when is_list(content_parts) ->
          Enum.map(content_parts, &convert_content_part(&1, model))
      end

    %{role: get_role(role), parts: parts}
  end

  defp convert_content_part(%{type: :text, content: text}, _model) do
    %{text: text}
  end

  defp convert_content_part(%{type: :image, content: image_data} = part, model) do
    if model_supports_vision?(model) do
      mime_type = Map.get(part, :mime_type) || detect_image_mime_type(image_data)
      %{
        inline_data: %{
          mime_type: mime_type,
          data: format_image_data(image_data)
        }
      }
    else
      %{text: "[Image not supported by this model]"}
    end
  end

  defp convert_content_part(%{type: :audio}, _model) do
    %{text: "[Audio not yet supported]"}
  end

  defp convert_content_part(%{type: :file}, _model) do
    %{text: "[Files not yet supported]"}
  end

  defp format_image_data("data:" <> data_with_header) do
    case String.split(data_with_header, ",", parts: 2) do
      [_header, base64_data] -> base64_data
      [base64_data] -> base64_data
    end
  end

  defp format_image_data(base64_data), do: base64_data

  defp detect_image_mime_type("data:image/" <> rest) do
    case String.split(rest, ";", parts: 2) do
      [mime_type, _] when mime_type in ["png", "jpeg", "jpg", "webp", "heic", "heif"] -> 
        "image/#{mime_type}"
      _ -> 
        "image/jpeg"
    end
  end

  defp detect_image_mime_type(_) do
    # Default to JPEG when format cannot be determined
    "image/jpeg"
  end

  defp model_supports_vision?(nil), do: true
  defp model_supports_vision?(model), do: get_in(@models, [model, :vision]) || false

  defp get_api_key do
    case Application.get_env(:lume, :gemini_api_key) || System.get_env("GEMINI_API_KEY") do
      nil -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  end

  defp make_request(model, endpoint, body, api_key, opts) do
    headers = [
      {"x-goog-api-key", api_key},
      {"content-type", "application/json"}
    ]

    url = "#{@base_url}/v1beta/models/#{model}:#{endpoint}"
    timeout = Keyword.get(opts, :timeout, 30_000)

    Req.new(headers: headers, receive_timeout: timeout)
    |> Lume.Circuit.attach_fuse(opts)
    |> Req.post(url: url, json: body)
  end

  defp make_stream_request(model, endpoint, body, api_key) do
    headers = [
      {"x-goog-api-key", api_key},
      {"content-type", "application/json"},
      {"accept", "text/event-stream"}
    ]

    url = "#{@base_url}/v1beta/models/#{model}:#{endpoint}?alt=sse"
    Req.post(url, json: body, headers: headers, into: :self)
  end

  defp extract_content_from_chunk(chunk) when is_map(chunk) do
    get_in(chunk, ["candidates", Access.at(0), "content", "parts", Access.at(0), "text"])
  end

  defp calculate_cost(model, usage) do
    pricing = get_in(@models, [model, :pricing]) || %{input: 0, output: 0}
    input_tokens = usage["promptTokenCount"] || 0
    output_tokens = usage["candidatesTokenCount"] || 0

    input_tokens * pricing.input / 1000 + output_tokens * pricing.output / 1000
  end
end
