defmodule Manipulators.DropAllHeaders do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    IO.inspect(headers, label: "Dropping headers")
    {[], connection}
  end
end
