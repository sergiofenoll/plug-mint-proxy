defmodule PlugMintProxy do
  @moduledoc """
  PlugMintProxy allows to proxy content from Plug
  """

  # @behaviour Plug

  # @default_opts %{ to: "redpencil.io", port: 80, kind: :http, path: "" }

  use Plug.Router

  def start(_argv) do
    port = 8888
    IO.puts "Starting Plug with Cowboy on port #{port}"
    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
    # :timer.sleep(:infinity)
  end

  plug Plug.Logger
  plug :match
  plug :dispatch

  match "/" do
    ConnectionForwarder.forward conn, "", "http://redpencil.io/"
    # {:ok, pid } = ConnectionForwarder.start_link( %{ scheme: :http, host: "redpencil.io", port: 80, base_path: "/" } )
    # {:ok, conn } = ConnectionForwarder.proxy( pid, conn )
    # conn
  end
  match "/hello/*path" do
    ConnectionForwarder.forward conn, path, "https://veeakker.be/"
    # {:ok, pid } = ConnectionForwarder.start_link( %{ scheme: :http, host: "redpencil.io", port: 80, base_path: "/" } )
    # {:ok, conn } = ConnectionForwarder.proxy( pid, conn )
    # conn
  end

  match "/nieuws/*path" do
    ConnectionForwarder.forward conn, path, "https://veeakker.be/nieuws/"
  end
end
