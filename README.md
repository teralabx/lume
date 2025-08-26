# Lume 🔮

A minimalistic, fluent AI client library for Elixir with first-class support for Google Gemini. Designed with simplicity, composability, and developer experience in mind.

## ✨ Features

- 🎯 **Simple, fluent API** - Chain operations naturally with Elixir's pipe operator
- 💎 **First-class Gemini support** - Full support for Gemini 2.5, 2.0, and 1.5 models
- 🖼️ **Multi-modal capabilities** - Text, vision, and embeddings in a unified interface  
- 🔄 **Streaming responses** - Real-time token streaming for responsive applications
- 📊 **Structured outputs** - Type-safe JSON responses with schema validation
- 💰 **Cost tracking** - Automatic token counting and cost calculation
- 🔁 **Retry & resilience** - Built-in retry logic and circuit breaker patterns
- 🎭 **Session management** - Maintain conversation context across interactions

## 📦 Installation

Add `lume` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lume, "~> 0.1.0"}
  ]
end
```

## 🚀 Quick Start with Gemini

### Configuration

Set your Gemini API key as an environment variable:

```bash
export GEMINI_API_KEY="your-api-key-here"
```

Or configure it in your application:

```elixir
# config/config.exs
config :lume, :gemini_api_key, System.get_env("GEMINI_API_KEY")
```

### Basic Usage

```elixir
# Simple text generation
{:ok, result} = 
  Lume.Gemini.flash()
  |> Lume.text("What is the meaning of life?")
  |> Lume.call()

IO.puts(result.last_result)
```

## 📚 Gemini Examples

### Text Generation

#### Basic Completion
```elixir
{:ok, result} =
  Lume.Gemini.flash()
  |> Lume.system("You are a helpful assistant.")
  |> Lume.text("Explain quantum computing in simple terms")
  |> Lume.call()

IO.puts(result.last_result)
# => "Quantum computing is like having a magical coin that can be both heads and tails at the same time..."
```

#### Using Different Models
```elixir
# Gemini 2.5 Flash (fast, efficient)
Lume.Gemini.flash()
|> Lume.text("Quick question: What's 2+2?")
|> Lume.call()

# Gemini 2.5 Pro (more capable, slower)  
Lume.Gemini.pro()
|> Lume.text("Write a detailed business plan for a startup")
|> Lume.call()

# Gemini 2.0 Flash (latest generation)
Lume.Gemini.flash_2_0()
|> Lume.text("Analyze this code for bugs")
|> Lume.call()

# Gemini 1.5 models (previous generation)
Lume.Gemini.flash_1_5()  # or Lume.Gemini.pro_1_5()
```

#### With Options
```elixir
{:ok, result} =
  Lume.Gemini.flash()
  |> Lume.text("Write a creative story about robots")
  |> Lume.opts(
    temperature: 0.9,      # Higher = more creative
    max_tokens: 1000,      # Limit response length
    timeout: 45_000        # Custom timeout in ms
  )
  |> Lume.call()
```

### 🎭 Conversation Management

#### Multi-turn Conversations
```elixir
# Start a conversation
{:ok, lume} =
  Lume.Gemini.flash()
  |> Lume.system("You are a math tutor. Be encouraging and helpful.")
  |> Lume.text("What is calculus?")
  |> Lume.call()

IO.puts(lume.last_result)
# => "Calculus is a branch of mathematics that studies continuous change..."

# Continue the conversation (maintains context)
{:ok, lume} =
  lume
  |> Lume.text("Can you give me an example?")
  |> Lume.call()

IO.puts(lume.last_result)  
# => "Of course! Let's think about a car's speed..."

# Check conversation history
IO.inspect(length(lume.messages))  # => 5 (system + 2 user + 2 assistant messages)
```

#### Session Management
```elixir
# Create a new session (clears message history)
lume = 
  Lume.Gemini.flash()
  |> Lume.system("You are helpful")
  |> Lume.text("Remember the number 42")
  |> Lume.new_session()

# lume.session != nil, but messages are cleared
```

### 🖼️ Vision Capabilities

#### Image Analysis
```elixir
# Analyze an image from base64 data
{:ok, result} =
  Lume.Gemini.flash()
  |> Lume.text("What's in this image?")
  |> Lume.image(base64_image_data, "image/jpeg")
  |> Lume.call()

# Using data URLs
image_data_url = "data:image/png;base64,iVBORw0KGgoAAAANS..."
{:ok, result} =
  Lume.Gemini.flash()
  |> Lume.text("Describe this image in detail")
  |> Lume.image(image_data_url)
  |> Lume.call()

# Multiple images in conversation
{:ok, lume} =
  Lume.Gemini.flash()
  |> Lume.system("Compare these images.")
  |> Lume.text("Compare these two images:")
  |> Lume.image(image1_base64)
  |> Lume.image(image2_base64)
  |> Lume.call()
```

#### Complex Multi-modal Requests
```elixir
{:ok, result} =
  Lume.Gemini.pro()
  |> Lume.system("You are an expert UI/UX designer")
  |> Lume.text("Analyze this app screenshot and suggest improvements:")
  |> Lume.image(screenshot_base64)
  |> Lume.text("Focus on accessibility and user experience.")
  |> Lume.opts(temperature: 0.3)  # Lower temperature for analytical tasks
  |> Lume.call()
```

### 🌊 Streaming Responses

#### Basic Streaming
```elixir
{:ok, stream} =
  Lume.Gemini.flash()
  |> Lume.text("Write a long story about space exploration")
  |> Lume.stream()

# Process chunks as they arrive
stream
|> Enum.each(fn chunk ->
  IO.write(chunk)  # Print each chunk as it arrives
end)
```

#### Streaming with Vision
```elixir
{:ok, stream} =
  Lume.Gemini.flash()
  |> Lume.text("Describe this image in great detail:")
  |> Lume.image(image_base64)
  |> Lume.stream()

# Collect first 10 chunks
chunks = stream |> Enum.take(10)
```

### 📊 Structured Outputs (JSON Schema)

#### Define Schema and Get Typed Responses
```elixir
# Define a schema for the response
person_schema = %{
  type: "object",
  properties: %{
    name: %{type: "string"},
    age: %{type: "number"},
    skills: %{
      type: "array",
      items: %{type: "string"}
    },
    experience_years: %{type: "number"}
  },
  required: ["name", "age", "skills"]
}

# Get structured response
{:ok, result} =
  Lume.Gemini.flash()
  |> Lume.text("Generate a profile for a senior Elixir developer")
  |> Lume.opts(response_schema: person_schema)
  |> Lume.call()

# Parse the JSON response
{:ok, profile} = Jason.decode(result.last_result)
IO.inspect(profile)
# => %{
#      "name" => "Alice Chen",
#      "age" => 32,
#      "skills" => ["Elixir", "Phoenix", "OTP", "PostgreSQL"],
#      "experience_years" => 8
#    }
```

#### Complex Nested Structures
```elixir
todo_schema = %{
  type: "object",
  properties: %{
    project_name: %{type: "string"},
    tasks: %{
      type: "array",
      items: %{
        type: "object",
        properties: %{
          title: %{type: "string"},
          description: %{type: "string"},
          priority: %{type: "string", enum: ["high", "medium", "low"]},
          estimated_hours: %{type: "number"}
        },
        required: ["title", "priority"]
      }
    }
  },
  required: ["project_name", "tasks"]
}

{:ok, result} =
  Lume.Gemini.flash()
  |> Lume.text("Create a development plan for building a chat application")
  |> Lume.opts(response_schema: todo_schema)
  |> Lume.call()

{:ok, plan} = Jason.decode(result.last_result)
```

### 🔢 Embeddings

#### Generate Text Embeddings
```elixir
# Basic embeddings with default settings (3072 dimensions)
{:ok, result} =
  Lume.new()
  |> Lume.text("The quick brown fox jumps over the lazy dog")
  |> Lume.Gemini.embeddings()

embeddings = result.last_result  # List of 3072 floats
```

#### Custom Dimensions and Task Types
```elixir
# For semantic similarity (768 dimensions)
{:ok, result} =
  Lume.new()
  |> Lume.text("Machine learning is fascinating")
  |> Lume.Gemini.embeddings(
    task_type: "SEMANTIC_SIMILARITY",
    output_dimensionality: 768
  )

# For retrieval systems
{:ok, query_embedding} =
  Lume.new()
  |> Lume.text("What is quantum computing?")
  |> Lume.Gemini.embeddings(
    task_type: "RETRIEVAL_QUERY",
    output_dimensionality: 1536
  )

{:ok, doc_embedding} =
  Lume.new()
  |> Lume.text("Quantum computing uses quantum bits...")
  |> Lume.Gemini.embeddings(
    task_type: "RETRIEVAL_DOCUMENT", 
    output_dimensionality: 1536
  )
```

#### Supported Dimensions
- 128, 256, 512, 768, 1536, 3072 (default)

#### Task Types
- `"SEMANTIC_SIMILARITY"` - For comparing text similarity
- `"RETRIEVAL_QUERY"` - For search queries
- `"RETRIEVAL_DOCUMENT"` - For documents to be searched
- `"CLASSIFICATION"` - For text classification tasks

### 💰 Cost and Token Tracking

```elixir
{:ok, lume} =
  Lume.Gemini.flash()
  |> Lume.text("Hello")
  |> Lume.call()

IO.puts("Cost: $#{lume.cost}")
IO.puts("Tokens used: #{lume.tokens_used}")

# Costs accumulate across multiple calls
{:ok, lume} =
  lume
  |> Lume.text("Tell me more")
  |> Lume.call()

IO.puts("Total cost: $#{lume.cost}")  # Cumulative cost
IO.puts("Total tokens: #{lume.tokens_used}")  # Cumulative tokens
```

### 🔄 Retry and Resilience

```elixir
# Automatic retries on failure
{:ok, result} =
  Lume.Gemini.flash()
  |> Lume.text("Important query")
  |> Lume.opts(
    retries: 3,           # Retry up to 3 times
    timeout: 60_000,      # 60 second timeout
    circuit_breaker: true # Enable circuit breaker
  )
  |> Lume.call()
```

### ⚡ Async Operations

```elixir
# Async call with callback
Lume.Gemini.flash()
|> Lume.text("Process this in background")
|> Lume.opts(
  async: true,
  callback: fn
    {:ok, result} -> IO.puts("Got result: #{result.last_result}")
    {:error, reason} -> IO.puts("Failed: #{inspect(reason)}")
  end
)
|> Lume.call()

# Simple async without callback
{:ok, task} =
  Lume.Gemini.flash()
  |> Lume.text("Background processing")
  |> Lume.call_async()

# Wait for result
{:ok, result} = Task.await(task)
```

### 🔗 Method Chaining

```elixir
# Build complex pipelines
result =
  Lume.Gemini.flash()
  |> Lume.system("You are a helpful assistant")
  |> Lume.text("Summarize this:")
  |> Lume.text("Artificial intelligence is transforming...")
  |> Lume.opts(temperature: 0.3, max_tokens: 200)
  |> Lume.call()
  |> case do
    {:ok, lume} -> 
      lume
      |> Lume.text("Now translate to Spanish")
      |> Lume.call()
    error -> 
      error
  end
```

## 🏗️ Advanced Patterns

### Pipeline Composition
```elixir
defmodule MyApp.AI do
  # Create reusable AI pipelines
  def creative_writer do
    Lume.Gemini.flash()
    |> Lume.system("You are a creative writer with vivid imagination")
    |> Lume.opts(temperature: 0.9)
  end
  
  def code_reviewer do
    Lume.Gemini.pro()
    |> Lume.system("You are an expert code reviewer. Be thorough but constructive.")
    |> Lume.opts(temperature: 0.2)
  end
  
  # Use the pipelines
  def write_story(prompt) do
    creative_writer()
    |> Lume.text(prompt)
    |> Lume.call()
  end
  
  def review_code(code) do
    code_reviewer()
    |> Lume.text("Review this Elixir code:\n```elixir\n#{code}\n```")
    |> Lume.call()
  end
end
```

### Custom Processing
```elixir
defmodule MyApp.Processor do
  def analyze_sentiment(text) do
    schema = %{
      type: "object",
      properties: %{
        sentiment: %{type: "string", enum: ["positive", "negative", "neutral"]},
        confidence: %{type: "number", minimum: 0, maximum: 1},
        key_phrases: %{type: "array", items: %{type: "string"}}
      },
      required: ["sentiment", "confidence"]
    }
    
    with {:ok, result} <- 
           Lume.Gemini.flash()
           |> Lume.text("Analyze sentiment: #{text}")
           |> Lume.opts(response_schema: schema)
           |> Lume.call(),
         {:ok, analysis} <- Jason.decode(result.last_result) do
      {:ok, analysis}
    end
  end
end
```

## 🎯 Model Selection Guide

| Model | Best For | Speed | Cost | Vision | Max Tokens |
|-------|----------|-------|------|--------|------------|
| `gemini-2.5-flash` | General use, quick responses | ⚡⚡⚡ | 💰 | ✅ | 8192 |
| `gemini-2.5-pro` | Complex tasks, better reasoning | ⚡⚡ | 💰💰 | ✅ | 8192 |
| `gemini-2.0-flash` | Latest features, experimental | ⚡⚡⚡ | 💰 | ✅ | 8192 |
| `gemini-1.5-flash` | Legacy, stable | ⚡⚡⚡ | 💰 | ✅ | 32768 |
| `gemini-1.5-pro` | Legacy, complex tasks | ⚡ | 💰💰💰 | ✅ | 32768 |

## 🔮 Upcoming Provider Support

- [ ] **Anthropic Claude** - Claude 3.5 Sonnet, Haiku
- [ ] **OpenAI** - GPT-4o, GPT-4o-mini, o1 series  
- [ ] **Mistral AI** - Mistral Large, Mixtral
- [ ] **Cohere** - Command, Embed models
- [ ] **Local Models** - Ollama, llama.cpp integration

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

Built with ❤️ by the TeraLabX team. Inspired by the simplicity of Ecto.Multi and the power of Elixir's pipe operator.

