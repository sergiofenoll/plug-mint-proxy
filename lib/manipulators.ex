defmodule AddMuSecretHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    {[{"hello", "world"} | headers], connection}
  end
end

defmodule DropAllHeaders do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    IO.inspect(headers, label: "Dropping headers")
    {[], connection}
  end
end

defmodule DropHostHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    new_headers =
      headers
      |> Enum.reject( &match?({"host", _}, &1) )

    {new_headers, connection}
  end
end

defmodule AddDefaultAllowedGroups do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    {[{"mu-auth-allowed-groups", "one-thousand"} | headers], connection}
  end
end
