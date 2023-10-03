defmodule EnvLog do
  @moduledoc """
  Abstraction allowing for logging of content only when certain
  environment variables are set on the project.

  Thes are most commonly read from the system environment variables, in
  which case they should be set on the element itself.
  """

  @type log_name ::
          :log_backend_communication
          | :log_frontend_communication
          | :log_request_processing
          | :log_response_processing
          | :log_connection_setup
          | :log_request_body
          | :log_response_body
          | :log_connection_failure
          | :log_connection_pool_processing
          | :log_proxy_url_on_call

  @spec log(log_name, any()) :: any()
  def log(name, content) do
    if Application.get_env(:plug_mint_proxy, name) do
      IO.puts(content)
    else
      :ok
    end
  end

  @spec inspect(any(), log_name, any()) :: any()
  def inspect(content, name, opts \\ []) do
    if Application.get_env(:plug_mint_proxy, name) do
      transform = Keyword.get(opts, :transform, fn x -> x end)

      content
      |> transform.()
      # credo:disable-for-next-line Credo.Check.Warning.IoInspect
      |> IO.inspect(Keyword.delete(opts, :transform))
    end

    content
  end
end
