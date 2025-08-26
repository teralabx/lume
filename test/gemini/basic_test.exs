defmodule Lume.Gemini.BasicTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  setup do
    case System.get_env("GEMINI_API_KEY") do
      nil ->
        {:skip, "GEMINI_API_KEY not set"}

      _key ->
        :ok
    end
  end

  describe "basic text completion" do
    test "simple text generation with Flash model" do
      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.system("You are a helpful assistant.")
        |> Lume.text("What is 2+2?")
        |> Lume.call()

      assert is_binary(result.last_result)
      assert String.contains?(result.last_result, "4")
      assert result.cost > 0
      assert result.tokens_used > 0
    end

    test "text generation with Pro model" do
      {:ok, result} =
        Lume.Gemini.pro()
        |> Lume.text("Write a haiku about code.")
        |> Lume.call()

      assert is_binary(result.last_result)
      assert result.cost > 0
      assert result.tokens_used > 0
    end

    test "text generation with temperature option" do
      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Tell me a creative story about robots.")
        |> Lume.opts(temperature: 0.9, timeout: 45_000)
        |> Lume.call()

      assert is_binary(result.last_result)
      assert String.length(result.last_result) > 50
    end

  end

  describe "conversation handling" do
    test "maintains conversation history" do
      {:ok, lume} =
        Lume.Gemini.flash()
        |> Lume.system("You are a math tutor.")
        |> Lume.text("What is 5 + 3?")
        |> Lume.call()

      # system, user, assistant
      assert length(lume.messages) == 3

      {:ok, continued} =
        lume
        |> Lume.text("What about 10 - 2?")
        |> Lume.call()

      # system, user, assistant, user, assistant
      assert length(continued.messages) == 5
      assert is_binary(continued.last_result)
    end

    test "handles new session" do
      lume =
        Lume.Gemini.flash()
        |> Lume.system("Test system")
        |> Lume.text("First message")
        |> Lume.new_session()

      assert lume.session != nil
      assert length(lume.messages) == 0
    end
  end

  describe "error handling" do
    test "handles missing API key gracefully" do
      original_key = System.get_env("GEMINI_API_KEY")

      try do
        System.delete_env("GEMINI_API_KEY")

        {:error, reason} =
          Lume.Gemini.flash()
          |> Lume.text("Test")
          |> Lume.call()

        assert reason == :missing_api_key
      after
        if original_key do
          System.put_env("GEMINI_API_KEY", original_key)
        end
      end
    end

    test "handles invalid model gracefully" do
      {:error, _reason} =
        Lume.new()
        |> Lume.provider(Lume.Providers.Gemini)
        |> Lume.model("invalid-model-name")
        |> Lume.text("Test")
        |> Lume.call()
    end
  end

  describe "cost and token tracking" do
    test "accumulates costs across multiple calls" do
      {:ok, lume1} =
        Lume.Gemini.flash()
        |> Lume.text("First call")
        |> Lume.call()

      first_cost = lume1.cost
      first_tokens = lume1.tokens_used

      {:ok, lume2} =
        lume1
        |> Lume.text("Second call")
        |> Lume.call()

      assert lume2.cost > first_cost
      assert lume2.tokens_used > first_tokens
    end
  end
end
