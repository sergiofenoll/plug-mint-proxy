defmodule PlugMintProxy do
  @moduledoc """
  PlugMintProxy allows to proxy content from Plug

  The routing process is governed by the Proxy module
  """

  use Application
  require Logger

  def start(_type, _args) do
    # public_port_env =
    #   System.get_env("PROXY_PORT") && elem(Integer.parse(System.get_env("PROXY_PORT")), 0)

    # port = public_port_env || 8888

    children = [
      {ConnectionPool, {}},
      # {Plug.Cowboy, scheme: :http, plug: Proxy, options: [port: port]}
    ]

    # Logger.info("PlugMintProxy started on #{port}")

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
