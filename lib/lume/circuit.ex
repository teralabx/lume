defmodule Lume.Circuit do
  @moduledoc """
  Circuit breaker utilities for API requests.
  """

  @doc """
  Add circuit breaker to Req client based on options.
  """
  def attach_fuse(req, opts) do
    case Keyword.get(opts, :fuse_opts) do
      true ->
        ReqFuse.attach(req,
          fuse_name: :lume_default_fuse,
          fuse_opts: {{:standard, 5, 60_000}, {:reset, 30_000}}
        )

      false ->
        req

      nil ->
        req

      custom when is_list(custom) ->
        ReqFuse.attach(req, custom)
    end
  end
end
