defmodule GeminiTest do
  use ExUnit.Case
  doctest Lume.Providers.Gemini

  alias Lume.Providers.Gemini

  describe "Gemini Provider Tests" do
    setup do
      api_key = System.get_env("GEMINI_API_KEY")
      if api_key, do: Application.put_env(:lume, :gemini_api_key, api_key)
      :ok
    end

    test "normal text generation - request building" do
      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.model("gemini-2.5-flash")
        |> Lume.system("You are a helpful assistant")
        |> Lume.text("Hello, how are you?")

      request = Gemini.build_request(lume)

      assert request[:contents] == [
               %{
                 role: "user",
                 parts: [%{text: "Hello, how are you?"}]
               }
             ]

      assert request[:system_instruction] == %{
               parts: [%{text: "You are a helpful assistant"}]
             }
    end

    @tag :integration
    test "normal text generation - real API call" do
      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.model("gemini-2.5-flash")
        |> Lume.system("You are a helpful assistant. Respond with exactly 'Hello there!'")
        |> Lume.text("Say hello")

      case Gemini.call(lume) do
        {:ok, result} ->
          IO.puts("Normal API Response: #{result.last_result}")
          IO.puts("Cost: $#{result.cost}")
          IO.puts("Tokens: #{result.tokens_used}")
          assert is_binary(result.last_result)
          assert result.cost > 0
          assert result.tokens_used > 0

        {:error, :missing_api_key} ->
          IO.puts("Skipping real API test - no API key")

        {:error, reason} ->
          flunk("API call failed: #{inspect(reason)}")
      end
    end

    test "structured output - request building" do
      schema = %{
        type: "object",
        properties: %{
          greeting: %{type: "string"}
        },
        required: ["greeting"]
      }

      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.model("gemini-2.5-pro")
        |> Lume.text("Say hello in JSON")
        |> Lume.opts(response_schema: schema)

      request = Gemini.build_request(lume)

      assert request[:generationConfig][:responseMimeType] == "application/json"
      assert request[:generationConfig][:responseSchema] == schema
    end

    @tag :integration
    test "structured output - real API call" do
      schema = %{
        type: "object",
        properties: %{
          greeting: %{type: "string"}
        },
        required: ["greeting"]
      }

      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.model("gemini-2.5-pro")
        |> Lume.text("Return a JSON object with a greeting field containing 'Hello World'")
        |> Lume.opts(response_schema: schema)

      case Gemini.call(lume) do
        {:ok, result} ->
          IO.puts("Structured Output Response: #{result.last_result}")
          IO.puts("Cost: $#{result.cost}")
          IO.puts("Tokens: #{result.tokens_used}")
          assert is_binary(result.last_result)
          # Should be valid JSON
          {:ok, json} = Jason.decode(result.last_result)
          assert Map.has_key?(json, "greeting")

        {:error, :missing_api_key} ->
          IO.puts("Skipping structured output test - no API key")

        {:error, reason} ->
          flunk("Structured output API call failed: #{inspect(reason)}")
      end
    end

    @tag :integration
    test "streaming - real API call" do
      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.model("gemini-2.5-flash")
        |> Lume.text(
          "Tell me a detailed story about a robot learning to paint. Make it at least 100 words and describe each step slowly."
        )

      case Gemini.stream(lume) do
        {:ok, stream} ->
          chunks = stream |> Enum.take(20) |> Enum.filter(&(&1 != nil))
          IO.puts("Streaming chunks received: #{length(chunks)}")

          chunks
          |> Enum.with_index()
          |> Enum.each(fn {chunk, i} ->
            IO.puts("Chunk #{i + 1}: '#{chunk}'")
          end)

          # Join all chunks to see full response
          full_response = Enum.join(chunks, "")
          IO.puts("Full response: #{full_response}")

          assert length(chunks) > 0
          assert Enum.all?(chunks, &is_binary/1)
          # For a longer story, we should get multiple chunks
          if length(chunks) > 1 do
            IO.puts("✓ Successfully got multiple streaming chunks!")
          else
            IO.puts("⚠ Only got one chunk - response might be too short for streaming")
          end

        {:error, :missing_api_key} ->
          IO.puts("Skipping streaming test - no API key")

        {:error, reason} ->
          flunk("Streaming API call failed: #{inspect(reason)}")
      end
    end

    test "image processing - request building" do
      image_data = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2w=="

      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.model("gemini-2.5-flash")
        |> Lume.text("What do you see in this image?")
        |> Lume.image(image_data)

      request = Gemini.build_request(lume)
      user_content = hd(request[:contents])
      parts = user_content[:parts]

      assert length(parts) == 2

      text_part = Enum.find(parts, &Map.has_key?(&1, :text))
      assert text_part[:text] == "What do you see in this image?"

      image_part = Enum.find(parts, &Map.has_key?(&1, :inline_data))
      assert image_part[:inline_data][:mime_type] == "image/jpeg"
      assert image_part[:inline_data][:data] == "/9j/4AAQSkZJRgABAQAAAQABAAD/2w=="
    end

    test "audio processing - request building" do
      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.text("Analyze this audio")
        |> Lume.audio("audio_data_placeholder")

      request = Gemini.build_request(lume)
      user_content = hd(request[:contents])
      parts = user_content[:parts]

      audio_part =
        Enum.find(parts, fn part ->
          Map.get(part, :text) == "[Audio not yet supported]"
        end)

      assert audio_part != nil
    end

    test "generation config - temperature and max tokens" do
      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.text("Generate creative content")
        |> Lume.opts(temperature: 0.8, max_tokens: 1000)

      request = Gemini.build_request(lume)

      assert request[:generationConfig][:temperature] == 0.8
      assert request[:generationConfig][:maxOutputTokens] == 1000
    end

    test "conversation history - multiple messages" do
      lume =
        Lume.new()
        |> Lume.provider(Gemini)
        |> Lume.system("You are a math tutor")
        |> Lume.text("What is 2 + 2?")

      assistant_message = %{
        role: :assistant,
        content: "2 + 2 equals 4",
        id: "test-id"
      }

      lume_with_history = %{lume | messages: lume.messages ++ [assistant_message]}
      lume_with_followup = Lume.text(lume_with_history, "What about 3 + 3?")

      request = Gemini.build_request(lume_with_followup)

      assert request[:system_instruction][:parts] == [%{text: "You are a math tutor"}]

      contents = request[:contents]
      assert length(contents) == 3
      assert Enum.at(contents, 0)[:role] == "user"
      assert Enum.at(contents, 1)[:role] == "model"
      assert Enum.at(contents, 2)[:role] == "user"
    end
  end
end
