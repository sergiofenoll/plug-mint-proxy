defmodule PlugMintProxy do
  @moduledoc """
  PlugMintProxy allows to proxy content from Plug

  The routing process is governed by the Proxy module
  """

  use Application
  require Logger

  def start(_type, _args) do
    children = [
      {ConnectionPool, {}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
