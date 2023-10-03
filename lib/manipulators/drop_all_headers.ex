defmodule Manipulators.DropAllHeaders do
  @moduledoc """
  Example manipulator which drops all headers.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(_headers, connection) do
    # IO.inspect(headers, label: "Dropping headers")
    {[], connection}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
