defmodule ProxyManipulatorSettings do
  @moduledoc "Configuration for proxy manipulators"

  @type connection_pair :: ProxyManipulator.connection_pair()
  @type headers :: ProxyManipulator.headers()

  defstruct request: [], response: []

  @type t :: %__MODULE__{request: [ProxyManipulator.t()], response: [ProxyManipulator.t()]}

  @doc "Constructs a new ProxyManipulatorSettings struct"
  def make_settings(request_manipulators, response_manipulators) do
    %__MODULE__{request: request_manipulators, response: response_manipulators}
  end

  @doc "Retrieves the manipulators for requests"
  def request_manipulators(%__MODULE__{request: request_manipulators}), do: request_manipulators
  @doc "Retrieves the manipulators for responses"
  def response_manipulators(%__MODULE__{response: response_manipulators}),
    do: response_manipulators

  @spec process_request_headers(headers(), t, connection_pair()) :: {headers(), connection_pair}
  def process_request_headers(headers, settings, connection_pair) do
    settings
    |> request_manipulators()
    |> Enum.map(&get_header_manipulator/1)
    |> run_manipulators(headers, connection_pair)
  end

  @spec process_response_headers(headers(), t, connection_pair()) :: {headers(), connection_pair}
  def process_response_headers(headers, settings, connection_pair) do
    settings
    |> response_manipulators()
    |> Enum.map(&get_header_manipulator/1)
    |> run_manipulators(headers, connection_pair)
  end

  @spec process_request_chunk(binary(), t, connection_pair()) :: {binary(), connection_pair}
  def process_request_chunk(chunk, settings, connection_pair) do
    settings
    |> request_manipulators()
    |> Enum.map(&get_chunk_manipulator/1)
    |> run_manipulators(chunk, connection_pair)
  end

  @spec process_response_chunk(binary(), t, connection_pair()) :: {binary(), connection_pair}
  def process_response_chunk(chunk, settings, connection_pair) do
    settings
    |> response_manipulators()
    |> Enum.map(&get_chunk_manipulator/1)
    |> run_manipulators(chunk, connection_pair)
  end

  # TODO: wire finish into connection_forwarder.ex
  @spec process_request_finish(boolean(), t, connection_pair()) :: {binary(), connection_pair}
  def process_request_finish(finish, settings, connection_pair) do
    settings
    |> request_manipulators()
    |> Enum.map(&get_finish_manipulator/1)
    |> run_manipulators(finish, connection_pair)
  end

  @spec process_response_finish(boolean(), t, connection_pair()) :: {binary(), connection_pair}
  def process_response_finish(finish, settings, connection_pair) do
    settings
    |> response_manipulators()
    |> Enum.map(&get_finish_manipulator/1)
    |> run_manipulators(finish, connection_pair)
  end

  @typep input_type :: headers() | binary() | boolean

  # Running the manipulators
  @spec run_manipulators(
          [
            (input, connection_pair() ->
               {input, connection_pair()}
               | :skip)
          ],
          input,
          connection_pair()
        ) :: {input, connection_pair()}
        when input: input_type
  defp run_manipulators([first_manipulator | rest], input, connection_pair) do
    case first_manipulator.(input, connection_pair) do
      :skip -> run_manipulators(rest, input, connection_pair)
      {input, connection_pair} -> run_manipulators(rest, input, connection_pair)
    end
  end

  defp run_manipulators([], input, connection_pair), do: {input, connection_pair}

  # Internal accessors
  @spec get_header_manipulator(any()) ::
          (headers, connection_pair -> {headers, connection_pair} | :skip)
  defp get_header_manipulator(module) do
    &module.headers/2
  end

  @spec get_chunk_manipulator(any()) ::
          (binary(), connection_pair -> {binary(), connection_pair} | :skip)
  defp get_chunk_manipulator(module) do
    &module.chunk/2
  end

  @spec get_finish_manipulator(any()) ::
          (boolean(), connection_pair -> {boolean(), connection_pair} | :skip)
  defp get_finish_manipulator(module) do
    &module.finish/2
  end
end
