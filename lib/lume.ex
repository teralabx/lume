defmodule Lume do
  @moduledoc """
  Lume - Minimalistic AI Client with chaining, cost tracking, and session management.
  Inspired by Ecto.Multi for building AI pipelines with resilience patterns.
  """

  @type content_part ::
          %{type: :text, content: String.t(), id: String.t()}
          | %{type: :image, content: String.t(), id: String.t()}
          | %{type: :audio, content: String.t(), id: String.t()}
          | %{type: :file, content: String.t(), filename: String.t(), id: String.t()}

  @type message :: %{
          role: :system | :user | :assistant,
          content: list(content_part()) | String.t(),
          id: String.t()
        }

  @type t :: %__MODULE__{
          provider_module: module() | nil,
          model: String.t() | nil,
          messages: list(message()),
          last_result: any() | nil,
          session: String.t() | nil,
          cost: float(),
          tokens_used: integer(),
          errors: list(String.t()),
          opts: keyword()
        }

  defstruct [
    :provider_module,
    :model,
    :last_result,
    messages: [],
    session: nil,
    cost: 0.0,
    tokens_used: 0,
    errors: [],
    opts: []
  ]

  def new, do: %__MODULE__{}

  def provider(lume, module) when is_atom(module) do
    %{lume | provider_module: module}
  end

  def model(lume, model_name) when is_binary(model_name) do
    %{lume | model: model_name}
  end

  def system(lume, content) do
    add_message(lume, :system, content)
  end

  def user(lume, content) do
    add_message(lume, :user, content)
  end

  def text(lume, content), do: user(lume, content)

  def image(lume, content, mime_type \\ nil) do
    case Lume.Media.process_content(content) do
      {:ok, processed_data} ->
        add_content_part(lume, :image, processed_data, nil, mime_type)

      {:error, reason} ->
        add_error(lume, "Invalid image content: #{reason}")
    end
  end

  def audio(lume, content) do
    case Lume.Media.process_content(content) do
      {:ok, processed_data} ->
        add_content_part(lume, :audio, processed_data)

      {:error, reason} ->
        add_error(lume, "Invalid audio content: #{reason}")
    end
  end

  # Throwing versions
  def image!(lume, content) do
    result = image(lume, content)
    if has_errors?(result), do: raise(ArgumentError, get_recent_error(result)), else: result
  end

  def audio!(lume, content) do
    result = audio(lume, content)
    if has_errors?(result), do: raise(ArgumentError, get_recent_error(result)), else: result
  end

  # Helper functions
  defp add_error(lume, error_message) do
    %{lume | errors: [error_message | lume.errors]}
  end

  defp has_errors?(%{errors: []}), do: false
  defp has_errors?(_), do: true

  defp get_recent_error(%{errors: [recent | _]}), do: recent
  defp get_recent_error(%{errors: []}), do: nil

  def file(lume, file_data, filename \\ "file") do
    add_content_part(lume, :file, file_data, filename)
  end

  def opts(lume, opts), do: %{lume | opts: Keyword.merge(lume.opts, opts)}

  def remove_message(lume, id) do
    %{lume | messages: Enum.reject(lume.messages, &(&1.id == id))}
  end

  # Private helpers
  defp add_message(lume, role, content) do
    message = %{
      role: role,
      content: content,
      id: next_id()
    }

    %{lume | messages: lume.messages ++ [message]}
  end

  defp add_content_part(lume, type, content, filename \\ nil, mime_type \\ nil) do
    part =
      case {filename, mime_type} do
        {nil, nil} ->
          %{type: type, content: content, id: next_id()}

        {filename, nil} ->
          %{type: type, content: content, filename: filename, id: next_id()}

        {nil, mime_type} ->
          %{type: type, content: content, mime_type: mime_type, id: next_id()}

        {filename, mime_type} ->
          %{type: type, content: content, filename: filename, mime_type: mime_type, id: next_id()}
      end

    # Add to last user message or create one
    case List.last(lume.messages) do
      %{role: :user} = msg ->
        updated_content =
          case msg.content do
            text when is_binary(text) ->
              [%{type: :text, content: text, id: next_id()}, part]

            parts when is_list(parts) ->
              parts ++ [part]
          end

        updated_msg = %{msg | content: updated_content}
        messages = List.replace_at(lume.messages, -1, updated_msg)
        %{lume | messages: messages}

      _ ->
        # No user message, create one
        add_message(lume, :user, [part])
    end
  end

  defp next_id do
    UUID.uuid4()
  end

  def new_session(lume) do
    session_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    %{lume | session: session_id, messages: []}
  end

  def call(%__MODULE__{provider_module: nil}), do: {:error, :no_provider}

  def call(%__MODULE__{provider_module: mod} = lume) do
    # Check for async option
    if Keyword.get(lume.opts, :async, false) do
      # Delegate to async module
      callback = Keyword.get(lume.opts, :callback)
      async_opts = Keyword.take(lume.opts, [:timeout, :supervisor, :on_timeout])
      Lume.Async.call(lume, callback, async_opts)
    else
      # Synchronous execution
      call_sync(lume, mod)
    end
  end

  # Synchronous call implementation (public for async module access)
  def call_sync(lume, mod) do
    retries = Keyword.get(lume.opts, :retries, 0)

    attempt = fn ->
      case mod.call(lume) do
        {:ok, updated_lume} ->
          # Add assistant response to conversation history
          assistant_message = %{
            role: :assistant,
            content: updated_lume.last_result,
            id: next_id()
          }

          final_lume = %{updated_lume | messages: updated_lume.messages ++ [assistant_message]}
          {:ok, final_lume}

        {:error, _} = err ->
          err
      end
    end

    Enum.reduce_while(0..retries, {:error, :all_retries_failed}, fn _, _acc ->
      case attempt.() do
        {:ok, res} ->
          {:halt, {:ok, res}}

        {:error, :missing_api_key} = err ->
          {:halt, err}

        {:error, reason} ->
          {:cont, {:error, reason}}
      end
    end)
  end

  def stream(%__MODULE__{provider_module: nil}), do: {:error, :no_provider}

  def stream(%__MODULE__{provider_module: mod} = lume) do
    mod.stream(lume)
  rescue
    UndefinedFunctionError -> {:error, :streaming_not_supported}
  end

  def embeddings(lume, opts \\ [])

  def embeddings(%__MODULE__{provider_module: nil}, _opts), do: {:error, :no_provider}

  def embeddings(%__MODULE__{provider_module: mod} = lume, opts) do
    mod.embeddings(lume, opts)
  rescue
    UndefinedFunctionError -> {:error, :embeddings_not_supported}
  end

  def call_async(%__MODULE__{provider_module: nil}), do: {:error, :no_provider}

  def call_async(%__MODULE__{} = lume) do
    task = Task.async(fn -> call(lume) end)
    {:ok, task}
  end

  def chain(lume, func) when is_function(func, 1) do
    case call(lume) do
      {:ok, updated_lume} -> func.(updated_lume)
      {:error, _} = err -> err
    end
  end
end
