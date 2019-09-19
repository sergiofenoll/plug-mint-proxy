defmodule Proxy do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  defmacro easy_forward(conn, path, endpoint) do
    endpoint_info =
      if is_binary(endpoint) do
        ConnectionForwarder.extract_info_from_backend_string(endpoint)
      else
        endpoint
      end

    IO.inspect(endpoint_info)

    quote do
      ConnectionForwarder.forward(
        unquote(conn),
        unquote(path),
        unquote(Macro.escape(endpoint_info))
      )
    end
  end

  match "/" do
    easy_forward(conn, [], "http://redpencil.io")
    # ConnectionForwarder.forward conn, [], "http://redpencil.io/"
    # {:ok, pid } = ConnectionForwarder.start_link( %{ scheme: :http, host: "redpencil.io", port: 80, base_path: "/" } )
    # {:ok, conn } = ConnectionForwarder.proxy( pid, conn )
    # conn
  end

  match "/hello/*path" do
    ConnectionForwarder.forward(conn, path, "https://veeakker.be/")

    # {:ok, pid } = ConnectionForwarder.start_link( %{ scheme: :http, host: "redpencil.io", port: 80, base_path: "/" } )
    # {:ok, conn } = ConnectionForwarder.proxy( pid, conn )
    # conn
  end

  match "/nieuws/*path" do
    ConnectionForwarder.forward(conn, path, "https://veeakker.be/nieuws/")
  end
end
