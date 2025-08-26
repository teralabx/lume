defmodule Lume.Async do
  @moduledoc """
  Asynchronous execution for Lume AI requests.

  ## Examples

      # Simple async
      task = Lume.Async.call(lume)
      result = Task.await(task)
      
      # With callback
      Lume.Async.call(lume, fn result -> handle(result) end)
      
      # Supervised (LiveView/GenServer)
      task = Lume.Async.call(lume, callback, supervisor: MyApp.TaskSupervisor)
      
      # Parallel processing
      results = Lume.Async.parallel_map(queries, &process/1, max_concurrency: 3)
  """

  @default_timeout 30_000

  @doc """
  Execute Lume request asynchronously.
  """
  def call(lume, callback \\ nil, opts \\ []) do
    task_fn = fn -> execute_sync(lume) end

    case {callback, Keyword.get(opts, :supervisor)} do
      {nil, nil} -> Task.async(task_fn)
      {nil, supervisor} -> Task.Supervisor.async_nolink(supervisor, task_fn)
      {callback, nil} -> start_with_callback(task_fn, callback)
      {callback, supervisor} -> start_supervised_with_callback(task_fn, callback, supervisor)
    end
  end

  @doc """
  Execute streaming request asynchronously.
  """
  def stream(lume, callback \\ nil, opts \\ []) do
    task_fn = fn -> Lume.stream(lume) end

    case {callback, Keyword.get(opts, :supervisor)} do
      {nil, nil} ->
        Task.async(task_fn)

      {nil, supervisor} ->
        Task.Supervisor.async_nolink(supervisor, task_fn)

      {callback, nil} ->
        start_stream_with_callback(task_fn, callback)

      {callback, supervisor} ->
        start_supervised_stream_with_callback(task_fn, callback, supervisor)
    end
  end

  @doc """
  Cancel a task safely.
  """
  def cancel(task_or_ref, reason \\ :shutdown) do
    Task.shutdown(task_or_ref, reason)
  end

  @doc """
  Wait for multiple tasks to complete.
  """
  def await_all(tasks, timeout \\ @default_timeout) do
    Task.await_many(tasks, timeout)
  end

  @doc """
  Execute requests in parallel with concurrency control.
  """
  def parallel_map(enumerable, fun, opts \\ []) do
    Task.async_stream(enumerable, fun, build_stream_opts(opts))
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:exit, reason}}
    end)
  end

  defp execute_sync(lume) do
    sync_lume = %{lume | opts: Keyword.delete(lume.opts, :async)}

    try do
      Lume.call_sync(sync_lume, sync_lume.provider_module)
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  defp start_with_callback(task_fn, callback) do
    Task.async(fn ->
      result = task_fn.()
      callback.(result)
      result
    end)
  end

  defp start_supervised_with_callback(task_fn, callback, supervisor) do
    Task.Supervisor.async_nolink(supervisor, fn ->
      result = task_fn.()
      callback.(result)
      result
    end)
  end

  defp start_stream_with_callback(task_fn, callback) do
    Task.async(fn ->
      handle_stream_result(task_fn.(), callback)
    end)
  end

  defp start_supervised_stream_with_callback(task_fn, callback, supervisor) do
    Task.Supervisor.async_nolink(supervisor, fn ->
      handle_stream_result(task_fn.(), callback)
    end)
  end

  defp handle_stream_result({:ok, stream}, callback) do
    stream
    |> Stream.each(&callback.({:chunk, &1}))
    |> Stream.run()

    callback.(:done)
    {:ok, stream}
  end

  defp handle_stream_result(error, callback) do
    callback.(error)
    error
  end

  defp build_stream_opts(opts) do
    [
      max_concurrency: Keyword.get(opts, :max_concurrency, 5),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      on_timeout: :kill_task
    ]
    |> maybe_add_supervisor(Keyword.get(opts, :supervisor))
  end

  defp maybe_add_supervisor(opts, nil), do: opts
  defp maybe_add_supervisor(opts, supervisor), do: Keyword.put(opts, :supervisor, supervisor)
end
