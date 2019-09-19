defmodule ConnectionPool do
  @name __MODULE__

  use GenServer


  def start_link(info) do
    GenServer.start_link(__MODULE__, info, name: @name)
  end

  @spec get_connection(ConnectionForwarder.connection_spec()) :: {:ok, pid()} | {:error, any()}
  def get_connection(connection_spec) do
    GenServer.call(@name, {:get_connection, connection_spec})
  end

  @spec get_new_connection(ConnectionForwarder.connection_spec()) ::
          {:ok, pid()} | {:error, any()}
  def get_new_connection(connection_spec) do
    ConnectionForwarder.start(connection_spec)
  end

  @spec return_connection(ConnectionForwarder.connection_spec(), pid()) :: :ok
  def return_connection(connection_spec, connection) do
    GenServer.cast(@name, {:return_connection, connection_spec, connection})
  end

  @spec remove_connection(ConnectionForwarder.connection_spec(), pid()) :: :ok
  def remove_connection(connection_spec, connection) do
    GenServer.cast(@name, {:remove_connection, connection_spec, connection})
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:return_connection, connection_spec, connection}, state) do
    IO.inspect( connection, label: "Returning connection" )
    new_state =
      state
      |> Map.update(connection_spec, [connection], fn values -> [connection | values] end)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection, connection_spec, connection}, state) do
    IO.inspect( connection, label: "Removing connection" )

    new_state =
      state
      |> Map.update(connection_spec, [], fn values ->
        Enum.reject(values, &(&1 == connection))
      end)

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_connection, connection_spec}, _from, state) do
    IO.inspect( connection_spec, label: "Retrieving connection for spec" )

    case Map.get(state, connection_spec) do
      [connection | rest] ->
        new_state = Map.update(state, connection_spec, [], fn _ -> rest end)

        {:reply, {:ok, connection}, new_state}

      _ ->
        {:reply, get_new_connection(connection_spec), state}
    end
  end
end
