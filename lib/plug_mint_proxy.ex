defmodule PlugMintProxy do
  @moduledoc """
  PlugMintProxy allows to proxy content from Plug

  The routing process is governed by the Proxy module
  """

  use Application

  def start(_type, _args) do
    children = [{ConnectionPool, {}}]
    opts = [strategy: :one_for:one, name: PlugMintProxy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
