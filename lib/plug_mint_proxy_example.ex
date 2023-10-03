defmodule PlugMintProxyExample do
  @moduledoc """
  An example implementation of a Proxy.

  The example here has two manipulators running on the request: one
  which drops the host header and one which adds the hello header.  The
  backend server will thus not receive the host header, but it will
  receive a hello header.

  The example also adds the hello header to the response.  Regardless of
  whether the backend replies with a hello header, it will be added by
  the manipulator.

  A few matching paths are returned to be used by this Proxy.  These are
  starting points.  You can use anything to get hold of a connection.
  """

  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  @request_manipulators [Manipulators.DropHostHeader, Manipulators.AddHelloWorldHeader]
  @response_manipulators [Manipulators.AddHelloWorldHeader]
  @manipulators ProxyManipulatorSettings.make_settings(
                  @request_manipulators,
                  @response_manipulators
                )

  def print_diagnostics do
    ProxyManipulatorSettings.print_diagnostics(@manipulators)
  end

  defmacro easy_forward(conn, path, endpoint) do
    endpoint_info =
      if is_binary(endpoint) do
        ConnectionForwarder.extract_info_from_backend_string(endpoint)
      else
        endpoint
      end

    quote do
      ConnectionForwarder.forward(
        unquote(conn),
        unquote(path),
        unquote(Macro.escape(endpoint_info)),
        @manipulators
      )
    end
  end

  match "/" do
    easy_forward(conn, [], "http://redpencil.io")
  end

  match "/editor-documents/*path" do
    ConnectionForwarder.forward(
      conn,
      path,
      "http://localhost:8080/editor-documents/",
      @manipulators
    )
  end

  match "/hello/*path" do
    ConnectionForwarder.forward(conn, path, "https://veeakker.be/", @manipulators)
  end

  match "/nieuws/*path" do
    ConnectionForwarder.forward(conn, path, "https://veeakker.be/nieuws/", @manipulators)
  end
end
