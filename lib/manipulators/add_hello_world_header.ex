defmodule Manipulators.AddHelloWorldHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    {[{"hello", "world"} | headers], connection}
  end
end
