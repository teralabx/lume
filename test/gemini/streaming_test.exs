defmodule Lume.Gemini.StreamingTest do
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

  describe "streaming responses" do
    test "streams text generation" do
      {:ok, stream} =
        Lume.Gemini.flash()
        |> Lume.text("Write a short story about a robot.")
        |> Lume.stream()

      chunks = stream |> Enum.take(10)

      assert length(chunks) > 0
      assert Enum.all?(chunks, &is_binary/1)

      # Combine chunks to form partial story
      combined = Enum.join(chunks, "")
      assert String.length(combined) > 0
    end

    test "streams with system prompt" do
      {:ok, stream} =
        Lume.Gemini.flash()
        |> Lume.system("You are a creative writer.")
        |> Lume.text("Tell me about the ocean.")
        |> Lume.stream()

      chunks = stream |> Enum.take(5)

      assert length(chunks) > 0
      assert Enum.all?(chunks, &is_binary/1)
    end

    test "streaming with temperature control" do
      {:ok, stream} =
        Lume.Gemini.flash()
        |> Lume.text("Generate creative names for a space station.")
        |> Lume.opts(temperature: 1.0)
        |> Lume.stream()

      chunks = stream |> Enum.take(8)

      assert length(chunks) > 0
      assert Enum.all?(chunks, &is_binary/1)
    end
  end

  describe "streaming edge cases" do
    test "handles empty responses gracefully" do
      {:ok, stream} =
        Lume.Gemini.flash()
        |> Lume.text("Respond with exactly one word: 'yes'")
        |> Lume.stream()

      chunks = stream |> Enum.to_list()

      assert length(chunks) >= 1
      combined = Enum.join(chunks, "")
      assert String.contains?(String.downcase(combined), "yes")
    end

    test "handles very short prompts" do
      {:ok, stream} =
        Lume.Gemini.flash()
        |> Lume.text("Hi")
        |> Lume.stream()

      chunks = stream |> Enum.take(3)

      assert length(chunks) > 0
      assert Enum.all?(chunks, &is_binary/1)
    end
  end

  describe "streaming with conversation" do
    test "streams continuation of conversation" do
      # First establish context
      {:ok, lume} =
        Lume.Gemini.flash()
        |> Lume.system("You are a helpful math tutor.")
        |> Lume.text("What is 2 + 2?")
        |> Lume.call()

      # Then stream a follow-up
      {:ok, stream} =
        lume
        |> Lume.text("Now explain why that's the answer.")
        |> Lume.stream()

      chunks = stream |> Enum.take(10)

      assert length(chunks) > 0
      assert Enum.all?(chunks, &is_binary/1)

      combined = Enum.join(chunks, "")
      assert String.length(combined) > 20
    end
  end

  describe "error handling in streaming" do
    test "handles API errors in streaming" do
      original_key = System.get_env("GEMINI_API_KEY")

      try do
        System.delete_env("GEMINI_API_KEY")

        {:error, reason} =
          Lume.Gemini.flash()
          |> Lume.text("Test streaming")
          |> Lume.stream()

        assert reason == :missing_api_key
      after
        if original_key do
          System.put_env("GEMINI_API_KEY", original_key)
        end
      end
    end

    test "handles invalid model in streaming" do
      {:error, _reason} =
        Lume.new()
        |> Lume.provider(Lume.Providers.Gemini)
        |> Lume.model("invalid-streaming-model")
        |> Lume.text("Test")
        |> Lume.stream()
    end
  end

  describe "streaming performance" do
    test "streams efficiently without blocking" do
      start_time = System.monotonic_time(:millisecond)

      {:ok, stream} =
        Lume.Gemini.flash()
        |> Lume.text("Write a detailed explanation of artificial intelligence.")
        |> Lume.stream()

      # Take first few chunks and measure time
      chunks = stream |> Enum.take(3)

      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      assert length(chunks) > 0
      # Should get first chunks quickly (within reasonable time)
      # 15 seconds max for first chunks (increased for network variability)
      assert elapsed < 15_000
    end
  end
end
