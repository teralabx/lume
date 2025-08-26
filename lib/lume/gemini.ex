defmodule Lume.Gemini do
  @moduledoc """
  Gemini provider shortcuts for easy model access.
  """

  def flash(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-2.5-flash")
  end

  def pro(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-2.5-pro")
  end

  def flash_2_0(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-2.0-flash")
  end

  def flash_1_5(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-1.5-flash")
  end

  def pro_1_5(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-1.5-pro")
  end

  @doc """
  Generate embeddings using Gemini embedding model.

  ## Options
  - `:task_type` - "SEMANTIC_SIMILARITY", "RETRIEVAL_QUERY", "RETRIEVAL_DOCUMENT", etc.
  - `:output_dimensionality` - 128, 256, 512, 768, 1536, or 3072

  ## Examples
      {:ok, result} = Lume.Gemini.embeddings(lume)
      {:ok, result} = Lume.Gemini.embeddings(lume, output_dimensionality: 768)
      
      # Direct text embedding
      {:ok, result} = Lume.new() 
      |> Lume.text("Hello world") 
      |> Lume.Gemini.embeddings()
  """
  def embeddings(lume, opts \\ []) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.embeddings(opts)
  end
end
