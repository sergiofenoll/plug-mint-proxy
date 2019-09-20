defmodule ProxyManipulator do
  @moduledoc "Manipulators allow you to manipulate requests"

  @optional_callbacks headers: 2, chunk: 2, finish: 2

  # No way to express an implementor of ProxyManipulator at this time, hence any()f
  @type t :: any()

  @type connection :: Plug.Conn.t() | Mint.HTTP.t()
  # @type connection_pair :: {incoming :: connection, outgoing :: connection}
  @type connection_pair :: {connection, connection}
  @type headers :: [{String.t(), String.t()}]

  @doc "Processes and converts the headers"
  @callback headers(headers, connection_pair) :: {headers, connection_pair} | :skip

  @doc "Processes and converts a chunk"
  @callback chunk(binary(), connection_pair) :: {binary, connection_pair} | :skip

  @doc "Processes and handles finishing the proxy"
  @callback finish(boolean, connection_pair) :: {boolean, connection_pair} | :skip
end
