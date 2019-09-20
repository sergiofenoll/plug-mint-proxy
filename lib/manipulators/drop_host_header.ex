defmodule Manipulators.DropHostHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    new_headers =
      headers
      |> Enum.reject( &match?({"host", _}, &1) )

    {new_headers, connection}
  end
end
