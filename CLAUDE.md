# Lume - Minimalistic AI Client Library

## Overview
Lume is a unified Elixir client library for multiple AI providers, supporting text generation, embeddings, image generation, video generation, and audio processing with a consistent interface. Inspired by Ecto.Multi for chaining operations with cost tracking, session management, and resilience patterns.

## Research Findings: AI Provider Patterns

### Streaming Patterns Across Providers
- **OpenAI**: Server-Sent Events (SSE) with token-by-token streaming, terminated by `[DONE]`
- **Gemini**: Chunk-based streaming with `GenerateContentResponse` objects, supports multi-modal streaming
- **Claude**: Rich event system with `message_start`, `content_block_delta`, `ping` events for fine-grained control

### Structured Output Patterns
- **OpenAI**: JSON Schema with `strict: true` for 100% compliance (gpt-4o-2024-08-06+)
- **Gemini**: `responseSchema` with JSON Schema subset, automatic with function calling
- **Claude**: Tool use pattern for structured outputs, integrated into message structure

### Common API Design Patterns
1. All use message-based chat completion formats
2. SSE streaming with `stream: true` parameter
3. Both sync/async execution modes supported natively
4. Schema-first approach for structured outputs
5. Event-driven streaming architecture

## Core Architecture

### Provider Behavior
```elixir
defmodule Lume.Provider do
  @type execution_mode :: :sync | :stream
  @type response_format :: :text | :json | :structured

  @callback build_request(lume :: Lume.t()) :: map()
  @callback call(lume :: Lume.t()) :: {:ok, Lume.t()} | {:error, any()}
  @callback stream(lume :: Lume.t()) :: {:ok, Stream.t()} | {:error, any()}

  @optional_callbacks [stream: 1]
end
```

### Main Struct (Ecto.Multi Inspired) - ✅ IMPLEMENTED
```elixir
defmodule Lume do
  @type t :: %__MODULE__{
    provider_module: module() | nil,
    model: String.t() | nil,            # specific model name
    system_prompt: String.t() | list(String.t()) | nil,
    text_prompt: String.t() | list(String.t()) | nil,
    images: list(String.t()) | nil,     # base64 encoded
    audio: list(String.t()) | nil,      # base64 encoded  
    file: String.t() | nil,             # file URL/path
    last_result: any() | nil,           # previous execution result
    history: list(any()),               # conversation history
    session: String.t() | nil,          # session ID for persistence
    cost: float(),                      # cumulative cost tracking
    tokens_used: integer(),             # cumulative token usage
    opts: keyword()                     # retry, fallback, etc.
  }

  defstruct [
    :provider_module,
    :model,
    :system_prompt, 
    :text_prompt,
    :images,
    :audio,
    :file,
    :last_result,
    history: [],
    session: nil,
    cost: 0.0,
    tokens_used: 0,
    opts: []
  ]

  # Core builder functions
  def new()
  def provider(lume, module)
  def model(lume, model_name)
  def system(lume, prompt)
  def text(lume, prompt)  
  def image(lume, image_data)
  def audio(lume, audio_data)
  def file(lume, url)
  def opts(lume, opts)

  # Session management
  def new_session(lume)

  # Execution with retry/fallback
  def call(lume)         # sync execution
  def stream(lume)       # streaming execution  
  def call_async(lume)   # async execution
  def chain(lume, func)  # multi-step chaining
end
```

### DSL Patterns

#### Function Chaining DSL
```elixir
{:ok, lume} =
  Lume.new()
  |> Lume.provider(Lume.Gemini.Flash)
  |> Lume.system("You are helpful")
  |> Lume.text("Tell me a joke")
  |> Lume.opts(retries: 2)
  |> Lume.call()
```

#### Macro Block DSL  
```elixir
import Lume.DSL

{:ok, lume} =
  lume do
    gemini :flash
    system "You are helpful"
    text "Tell me a joke" 
    opts retries: 2
    call()
  end
```

## Implementation Status

### ✅ COMPLETED - Core Providers

#### OpenAI Provider (`Lume.Providers.OpenAI`)
**Models Implemented:**
- `gpt-4o` - Latest flagship model with vision support
- `gpt-4o-mini` - Cost-efficient model (60% cheaper than GPT-3.5)
- `gpt-4-turbo` - Enhanced capabilities with vision
- `o1-preview` - Advanced reasoning model  
- `o1-mini` - Smaller reasoning model

**Features:**
- ✅ Text-to-text completion
- ✅ Vision support (image-to-text)
- ✅ Streaming with SSE
- ✅ Structured outputs with JSON Schema + strict mode
- ✅ Cost tracking with accurate per-model pricing
- ✅ Retry/fallback mechanisms
- ✅ Request building with proper message formats

#### Gemini Provider (`Lume.Providers.Gemini`)
**Models Implemented:**
- `gemini-2.5-flash` - Latest best price-performance model
- `gemini-2.5-pro` - Most advanced reasoning model 
- `gemini-2.0-flash` - Next-gen features and improved capabilities
- `gemini-1.5-flash` - Efficient workhorse model
- `gemini-1.5-pro` - Mid-size multimodal model

**Features:**
- ✅ Text-to-text completion
- ✅ Vision support (multimodal with inline_data)
- ✅ Streaming with SSE (`alt=sse`)
- ✅ Structured outputs with responseSchema
- ✅ Cost tracking with accurate Gemini pricing
- ✅ Safety settings configuration
- ✅ Generation config (temperature, max tokens)

### ✅ DSL Shortcuts Implemented

```elixir
# OpenAI shortcuts
Lume.OpenAI.gpt4o()      # GPT-4o model
Lume.OpenAI.gpt4o_mini() # GPT-4o mini
Lume.OpenAI.o1()         # o1-preview
Lume.OpenAI.o1_mini()    # o1-mini

# Gemini shortcuts  
Lume.Gemini.flash()      # Gemini 2.5 Flash
Lume.Gemini.pro()        # Gemini 2.5 Pro
Lume.Gemini.flash_2_0()  # Gemini 2.0 Flash
```

### ✅ Live Testing Results
```bash
=== Gemini Test Results ===
✓ DSL construction works
✓ Request building works  
✓ Live API call successful
✓ Cost tracking: $5.95e-6 for 36 tokens
✓ Response parsing works
```

### ✅ Current Usage Examples

#### Basic Text Generation
```elixir
# Simple Gemini call
{:ok, result} = Lume.Gemini.flash()
|> Lume.system("You are a helpful assistant")
|> Lume.text("Explain quantum computing in one sentence")
|> Lume.call()

# OpenAI with options
{:ok, result} = Lume.OpenAI.gpt4o_mini()
|> Lume.text("Write a haiku about code")
|> Lume.opts(temperature: 0.9, retries: 2)
|> Lume.call()
```

#### Vision (Image-to-Text)
```elixir
# OpenAI vision
{:ok, result} = Lume.OpenAI.gpt4o()
|> Lume.system("Describe what you see in detail")
|> Lume.text("What's happening in this image?")
|> Lume.image("data:image/jpeg;base64,/9j/4AAQ...")
|> Lume.call()

# Gemini vision
{:ok, result} = Lume.Gemini.flash()
|> Lume.text("Analyze this screenshot")
|> Lume.image("iVBORw0KGgoAAAANSU...")
|> Lume.call()
```

#### Structured Output
```elixir
schema = %{
  type: "object", 
  properties: %{
    name: %{type: "string"},
    skills: %{type: "array", items: %{type: "string"}}
  },
  required: ["name", "skills"]
}

{:ok, result} = Lume.OpenAI.gpt4o()
|> Lume.text("Generate a developer profile")
|> Lume.opts(response_schema: schema)
|> Lume.call()
```

#### Streaming
```elixir
{:ok, stream} = Lume.Gemini.flash()
|> Lume.text("Write a story about AI")
|> Lume.stream()

stream |> Enum.each(&IO.write/1)
```

## Provider Modules (Future Extensions)

### Text Generation Providers

#### OpenAI
```elixir
defmodule Lume.OpenAI do
  # Chat completions
  @spec gpt4o(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def gpt4o(lume, opts \\ [])

  @spec gpt4o_mini(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def gpt4o_mini(lume, opts \\ [])

  @spec o1(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def o1(lume, opts \\ [])

  @spec o1_mini(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def o1_mini(lume, opts \\ [])

  # Embeddings
  @spec embeddings(Lume.t(), keyword()) :: {:ok, list(float())} | {:error, any()}
  def embeddings(lume, opts \\ [])

  # Image generation
  @spec dalle3(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def dalle3(prompt, opts \\ [])

  @spec dalle2(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def dalle2(prompt, opts \\ [])

  # Audio
  @spec whisper(Lume.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def whisper(lume, opts \\ [])

  @spec tts(String.t(), keyword()) :: {:ok, binary()} | {:error, any()}
  def tts(text, opts \\ [])
end
```

#### Anthropic
```elixir
defmodule Lume.Anthropic do
  @spec sonnet(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def sonnet(lume, opts \\ [])

  @spec haiku(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def haiku(lume, opts \\ [])

  @spec opus(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def opus(lume, opts \\ [])
end
```

#### Google Gemini  
```elixir
defmodule Lume.Gemini do
  # Chat completions
  @spec flash(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def flash(lume, opts \\ [])

  @spec pro(Lume.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def pro(lume, opts \\ [])

  # Embeddings
  @spec embeddings(Lume.t(), keyword()) :: {:ok, list(float())} | {:error, any()}
  def embeddings(lume, opts \\ [])

  # Image generation
  @spec imagen3(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def imagen3(prompt, opts \\ [])

  # Video generation
  @spec veo(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def veo(prompt, opts \\ [])
end
```

#### OpenRouter
```elixir
defmodule Lume.OpenRouter do
  @spec call(Lume.t(), String.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def call(lume, model_name, opts \\ [])

  @spec embeddings(Lume.t(), String.t(), keyword()) :: {:ok, list(float())} | {:error, any()}
  def embeddings(lume, model_name, opts \\ [])
end
```

### Specialized Generation Providers

#### RunwayML
```elixir
defmodule Lume.Runway do
  @spec gen3(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def gen3(prompt, opts \\ [])

  @spec gen3_turbo(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def gen3_turbo(prompt, opts \\ [])
end
```

#### Stability AI
```elixir
defmodule Lume.Stability do
  @spec sd3(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def sd3(prompt, opts \\ [])

  @spec sdxl(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def sdxl(prompt, opts \\ [])

  @spec video(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def video(prompt, opts \\ [])
end
```

#### Midjourney (via API)
```elixir
defmodule Lume.Midjourney do
  @spec imagine(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def imagine(prompt, opts \\ [])

  @spec upscale(String.t(), integer(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def upscale(job_id, index, opts \\ [])
end
```

#### ElevenLabs
```elixir
defmodule Lume.ElevenLabs do
  @spec tts(String.t(), keyword()) :: {:ok, binary()} | {:error, any()}
  def tts(text, opts \\ [])

  @spec voice_clone(binary(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def voice_clone(audio_sample, opts \\ [])
end
```

## Chaining and Utilities

### Chain Operations
```elixir
defmodule Lume.Chain do
  @spec extract_result(any()) :: String.t()
  def extract_result(response)

  @spec extract_url(any()) :: String.t() | nil
  def extract_url(response)

  @spec extract_embeddings(any()) :: list(float()) | nil
  def extract_embeddings(response)

  @spec pipe(Lume.t(), list(function())) :: {:ok, any()} | {:error, any()}
  def pipe(lume, operations)
end
```

### File Utilities
```elixir
defmodule Lume.Utils do
  @spec encode_image(String.t() | binary()) :: String.t()
  def encode_image(image_path_or_data)

  @spec encode_audio(String.t() | binary()) :: String.t()
  def encode_audio(audio_path_or_data)

  @spec decode_base64(String.t()) :: binary()
  def decode_base64(encoded_data)

  @spec save_file(binary(), String.t()) :: :ok | {:error, any()}
  def save_file(data, path)
end
```

## Usage Examples

### Basic Text Generation
```elixir
# Simple prompt
result = Lume.new()
|> Lume.system("You are a helpful assistant")
|> Lume.prompt("What is 2+2?")
|> Lume.Gemini.flash(temperature: 0.7)

# With images
result = Lume.new()
|> Lume.system("Describe this image in detail")
|> Lume.image("/path/to/image.jpg")
|> Lume.OpenAI.gpt4o()
```

### Embeddings
```elixir
embeddings = Lume.new()
|> Lume.text("The quick brown fox jumps over the lazy dog")
|> Lume.OpenAI.embeddings()
```

### Image Generation
```elixir
image_url = Lume.OpenAI.dalle3(
  "A futuristic city at sunset with flying cars",
  size: "1024x1024",
  quality: "hd"
)

# Or with Stability AI
image_url = Lume.Stability.sd3(
  "A majestic dragon in a mystical forest",
  steps: 50,
  cfg_scale: 7.0
)
```

### Video Generation
```elixir
video_url = Lume.Runway.gen3(
  "A cat walking through a busy street",
  duration: 10,
  resolution: "1280x768"
)

# Or with Google Veo
video_url = Lume.Gemini.veo(
  "Time-lapse of flowers blooming in spring",
  duration: 5
)
```

### Audio Processing
```elixir
# Text to speech
audio_data = Lume.ElevenLabs.tts(
  "Hello, this is a test of text to speech",
  voice_id: "21m00Tcm4TlvDq8ikWAM"
)

# Speech to text
transcript = Lume.new()
|> Lume.audio("/path/to/audio.mp3")
|> Lume.OpenAI.whisper()
```

### Complex Chaining
```elixir
# Generate image description, then create similar image
result = Lume.new()
|> Lume.system("Describe this image for image generation")
|> Lume.image("/path/to/input.jpg")
|> Lume.OpenAI.gpt4o()
|> Lume.chain(fn response ->
    description = Lume.Chain.extract_result(response)
    Lume.Stability.sd3(description, steps: 30)
  end)

# Multi-modal chain: image -> description -> embeddings
result = Lume.new()
|> Lume.image("/path/to/image.jpg")
|> Lume.Anthropic.sonnet()
|> Lume.chain(fn response ->
    text = Lume.Chain.extract_result(response)
    Lume.new()
    |> Lume.text(text)
    |> Lume.OpenAI.embeddings()
  end)
```

## Configuration

### ✅ Current API Keys Support
```elixir
# Environment variables (recommended)
export OPENAI_API_KEY="sk-..."
export GEMINI_API_KEY="AI..."

# Or config/config.exs
config :lume,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  gemini_api_key: System.get_env("GEMINI_API_KEY")
```

### Future Configuration Options
```elixir
# config/config.exs (planned)
config :lume,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  gemini_api_key: System.get_env("GEMINI_API_KEY"),
  stability_api_key: System.get_env("STABILITY_API_KEY"),
  elevenlabs_api_key: System.get_env("ELEVENLABS_API_KEY"),
  runway_api_key: System.get_env("RUNWAY_API_KEY"),
  openrouter_api_key: System.get_env("OPENROUTER_API_KEY"),
  request_timeout: 60_000,
  max_retries: 3
```

## Dependencies ✅ CONFIGURED
- `jason ~> 1.4`: JSON encoding/decoding
- `req ~> 0.5.0`: HTTP client for API requests

## Development Commands ✅ WORKING
```bash
mix deps.get       # Install dependencies
mix compile        # Compile project
mix run test_gemini.exs  # Run live tests
```

## Implementation Summary

**✅ COMPLETED FEATURES:**
- Complete Lume struct with cost tracking, session management
- Full OpenAI provider (GPT-4o, GPT-4o-mini, o1 series)
- Full Gemini provider (2.5 Flash/Pro, 2.0 Flash, 1.5 series)
- Vision support for both providers
- Streaming support with SSE
- Structured outputs with JSON schema
- Clean DSL with function chaining
- Provider shortcuts (Lume.OpenAI.gpt4o, Lume.Gemini.flash)
- Live testing and validation
- Cost and token tracking
- Retry/fallback mechanisms
- Async support

**🔧 NEXT STEPS:**
- Add Anthropic Claude provider
- Add macro-based block DSL
- Add more provider shortcuts
- Add embeddings support
- Add audio/image generation providers
- memorize all the findings so far
