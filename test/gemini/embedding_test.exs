defmodule Lume.Gemini.EmbeddingTest do
  use ExUnit.Case, async: true

  describe "Gemini embeddings via unified flow" do
    @tag :live
    test "basic embedding via Lume.Gemini shortcuts" do
      {:ok, result} =
        Lume.new()
        |> Lume.text("The quick brown fox jumps over the lazy dog")
        |> Lume.Gemini.embeddings()

      assert is_list(result.last_result)
      # Default dimension
      assert length(result.last_result) == 3072
      assert Enum.all?(result.last_result, &is_float/1)
    end

    @tag :live
    test "embedding with custom dimensions" do
      {:ok, result} =
        Lume.new()
        |> Lume.text("Machine learning and artificial intelligence")
        |> Lume.Gemini.embeddings(output_dimensionality: 768, task_type: "SEMANTIC_SIMILARITY")

      assert is_list(result.last_result)
      assert length(result.last_result) == 768
      assert Enum.all?(result.last_result, &is_float/1)
    end

    @tag :live
    test "embedding via unified Lume.embeddings flow" do
      {:ok, result} =
        Lume.new()
        |> Lume.provider(Lume.Providers.Gemini)
        |> Lume.system("You are a helpful assistant")
        |> Lume.text("Tell me about quantum computing")
        |> Lume.text("And also about machine learning")
        |> Lume.embeddings()

      assert is_list(result.last_result)
      assert length(result.last_result) == 3072
      assert Enum.all?(result.last_result, &is_float/1)
    end

    @tag :live
    test "embedding with chaining and custom dimensions" do
      {:ok, result} =
        Lume.new()
        |> Lume.text("Hello world")
        |> Lume.provider(Lume.Providers.Gemini)
        |> Lume.embeddings(output_dimensionality: 1536)

      assert is_list(result.last_result)
      assert length(result.last_result) == 1536
      assert Enum.all?(result.last_result, &is_float/1)
    end

    @tag :live
    test "embedding with different task types" do
      # Test retrieval query task type
      {:ok, result1} =
        Lume.new()
        |> Lume.text("What is machine learning?")
        |> Lume.Gemini.embeddings(task_type: "RETRIEVAL_QUERY", output_dimensionality: 768)

      # Test retrieval document task type  
      {:ok, result2} =
        Lume.new()
        |> Lume.text(
          "Machine learning is a subset of artificial intelligence that focuses on algorithms."
        )
        |> Lume.Gemini.embeddings(task_type: "RETRIEVAL_DOCUMENT", output_dimensionality: 768)

      assert is_list(result1.last_result)
      assert is_list(result2.last_result)
      assert length(result1.last_result) == 768
      assert length(result2.last_result) == 768

      # Embeddings should be different for different task types
      refute result1.last_result == result2.last_result
    end
  end

  describe "error handling" do
    test "returns error when no provider is set" do
      result =
        Lume.new()
        |> Lume.text("Hello world")
        |> Lume.embeddings()

      assert result == {:error, :no_provider}
    end

    test "returns error when provider doesn't support embeddings" do
      # Create a mock provider that doesn't implement embeddings
      defmodule MockProvider do
        @behaviour Lume.Provider

        def build_request(_lume), do: %{}
        def call(_lume), do: {:ok, %Lume{}}
      end

      result =
        Lume.new()
        |> Lume.provider(MockProvider)
        |> Lume.text("Hello world")
        |> Lume.embeddings()

      assert result == {:error, :embeddings_not_supported}
    end

    @tag :live
    test "handles minimal text input" do
      # Test with minimal text content
      {:ok, result} =
        Lume.new()
        |> Lume.text("Hi")
        |> Lume.Gemini.embeddings()

      assert is_list(result.last_result)
      assert length(result.last_result) == 3072
    end
  end

  describe "message processing" do
    @tag :live
    test "combines multiple text messages" do
      {:ok, result} =
        Lume.new()
        |> Lume.text("First part")
        |> Lume.text("Second part")
        |> Lume.text("Third part")
        |> Lume.Gemini.embeddings()

      assert is_list(result.last_result)
      assert length(result.last_result) == 3072
    end

    @tag :live
    test "extracts text from mixed content messages" do
      {:ok, result} =
        Lume.new()
        |> Lume.system("You are helpful")
        |> Lume.text("Main content")
        |> Lume.Gemini.embeddings()

      assert is_list(result.last_result)
      assert length(result.last_result) == 3072
    end
  end

  describe "dimension validation" do
    @tag :live
    test "supports various output dimensions" do
      dimensions = [128, 256, 512, 768, 1536, 3072]

      for dim <- dimensions do
        {:ok, result} =
          Lume.new()
          |> Lume.text("Test text for dimension #{dim}")
          |> Lume.Gemini.embeddings(output_dimensionality: dim)

        assert is_list(result.last_result)

        assert length(result.last_result) == dim,
               "Expected #{dim} dimensions, got #{length(result.last_result)}"
      end
    end
  end
end
