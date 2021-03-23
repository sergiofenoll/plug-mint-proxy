defmodule Manipulators.AddHelloWorldHeader do
  @moduledoc """
  Example manipulator which adds a "hello" header with value "world".
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    {[{"hello", "world"} | headers], connection}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
