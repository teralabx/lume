defmodule Lume.Gemini.StructuredOutputTest do
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

  describe "JSON schema responses" do
    test "generates structured person profile" do
      schema = %{
        type: "object",
        properties: %{
          name: %{type: "string"},
          age: %{type: "number"},
          skills: %{
            type: "array",
            items: %{type: "string"}
          }
        },
        required: ["name", "age", "skills"]
      }

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.system("Generate realistic developer profiles.")
        |> Lume.text("Create a profile for a senior software engineer.")
        |> Lume.opts(response_schema: schema)
        |> Lume.call()

      assert is_binary(result.last_result)

      # Parse JSON response
      {:ok, parsed} = Jason.decode(result.last_result)

      assert is_map(parsed)
      assert is_binary(parsed["name"])
      assert is_number(parsed["age"])
      assert is_list(parsed["skills"])
      assert length(parsed["skills"]) > 0
      assert Enum.all?(parsed["skills"], &is_binary/1)
    end

    test "generates structured product information" do
      schema = %{
        type: "object",
        properties: %{
          name: %{type: "string"},
          price: %{type: "number"},
          category: %{type: "string"},
          features: %{
            type: "array",
            items: %{type: "string"}
          },
          inStock: %{type: "boolean"}
        },
        required: ["name", "price", "category"]
      }

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Generate product information for a laptop.")
        |> Lume.opts(response_schema: schema)
        |> Lume.call()

      assert is_binary(result.last_result)

      {:ok, parsed} = Jason.decode(result.last_result)

      assert is_map(parsed)
      assert is_binary(parsed["name"])
      assert is_number(parsed["price"])
      assert is_binary(parsed["category"])

      if Map.has_key?(parsed, "features") do
        assert is_list(parsed["features"])
      end

      if Map.has_key?(parsed, "inStock") do
        assert is_boolean(parsed["inStock"])
      end
    end

    test "generates list of structured items" do
      schema = %{
        type: "object",
        properties: %{
          items: %{
            type: "array",
            items: %{
              type: "object",
              properties: %{
                title: %{type: "string"},
                description: %{type: "string"},
                priority: %{type: "string", enum: ["high", "medium", "low"]}
              },
              required: ["title", "description", "priority"]
            }
          }
        },
        required: ["items"]
      }

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Generate 3 todo items for a software project.")
        |> Lume.opts(response_schema: schema)
        |> Lume.call()

      assert is_binary(result.last_result)

      {:ok, parsed} = Jason.decode(result.last_result)

      assert is_map(parsed)
      assert is_list(parsed["items"])
      assert length(parsed["items"]) >= 1

      first_item = List.first(parsed["items"])
      assert is_binary(first_item["title"])
      assert is_binary(first_item["description"])
      assert first_item["priority"] in ["high", "medium", "low"]
    end
  end

  describe "schema with different types" do
    test "handles number and boolean types" do
      schema = %{
        type: "object",
        properties: %{
          score: %{type: "number", minimum: 0, maximum: 100},
          passed: %{type: "boolean"},
          feedback: %{type: "string"}
        },
        required: ["score", "passed"]
      }

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Evaluate a student's performance: they got 8 out of 10 questions correct.")
        |> Lume.opts(response_schema: schema)
        |> Lume.call()

      assert is_binary(result.last_result)

      {:ok, parsed} = Jason.decode(result.last_result)

      assert is_map(parsed)
      assert is_number(parsed["score"])
      assert parsed["score"] >= 0
      assert parsed["score"] <= 100
      assert is_boolean(parsed["passed"])

      if Map.has_key?(parsed, "feedback") do
        assert is_binary(parsed["feedback"])
      end
    end

    test "handles enum constraints" do
      schema = %{
        type: "object",
        properties: %{
          weather: %{type: "string", enum: ["sunny", "cloudy", "rainy", "snowy"]},
          temperature: %{type: "number"},
          description: %{type: "string"}
        },
        required: ["weather"]
      }

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Describe today's weather in a city of your choice.")
        |> Lume.opts(response_schema: schema)
        |> Lume.call()

      assert is_binary(result.last_result)

      {:ok, parsed} = Jason.decode(result.last_result)

      assert is_map(parsed)
      assert parsed["weather"] in ["sunny", "cloudy", "rainy", "snowy"]

      if Map.has_key?(parsed, "temperature") do
        assert is_number(parsed["temperature"])
      end
    end
  end

  describe "structured output with conversation" do
    test "maintains structure across conversation turns" do
      schema = %{
        type: "object",
        properties: %{
          answer: %{type: "string"},
          confidence: %{type: "number", minimum: 0, maximum: 1}
        },
        required: ["answer", "confidence"]
      }

      {:ok, lume} =
        Lume.Gemini.flash()
        |> Lume.system("Answer questions with confidence scores.")
        |> Lume.text("What is the capital of France?")
        |> Lume.opts(response_schema: schema)
        |> Lume.call()

      {:ok, first_response} = Jason.decode(lume.last_result)
      assert is_binary(first_response["answer"])
      assert is_number(first_response["confidence"])

      {:ok, continued} =
        lume
        |> Lume.text("What about Germany?")
        |> Lume.opts(response_schema: schema)
        |> Lume.call()

      {:ok, second_response} = Jason.decode(continued.last_result)
      assert is_binary(second_response["answer"])
      assert is_number(second_response["confidence"])
    end
  end

  describe "error handling with schemas" do
    test "handles invalid schema gracefully" do
      invalid_schema = %{
        type: "invalid_type",
        properties: "this should be a map"
      }

      {:error, _reason} =
        Lume.Gemini.flash()
        |> Lume.text("Generate something")
        |> Lume.opts(response_schema: invalid_schema)
        |> Lume.call()
    end

    test "handles missing required properties in schema" do
      # Schema without required field
      minimal_schema = %{
        type: "object",
        properties: %{
          name: %{type: "string"}
        }
        # No required field specified
      }

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Generate a simple object with a name")
        |> Lume.opts(response_schema: minimal_schema)
        |> Lume.call()

      # Should still work even without strict requirements
      assert is_binary(result.last_result)
      {:ok, _parsed} = Jason.decode(result.last_result)
    end
  end

  describe "schema validation and cost tracking" do
    test "tracks cost for structured outputs" do
      schema = %{
        type: "object",
        properties: %{
          summary: %{type: "string"},
          word_count: %{type: "number"}
        },
        required: ["summary", "word_count"]
      }

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Summarize the concept of machine learning")
        |> Lume.opts(response_schema: schema)
        |> Lume.call()

      assert is_binary(result.last_result)
      assert result.cost > 0
      assert result.tokens_used > 0

      {:ok, parsed} = Jason.decode(result.last_result)
      assert is_binary(parsed["summary"])
      assert is_number(parsed["word_count"])
    end
  end
end