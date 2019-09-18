defmodule ConnectionForwarder do
  use GenServer

  require Logger

  def start_link(%{scheme: _scheme, host: _host, port: _port, base_path: _base_path} = options) do
    IO.puts("Going to init connection")
    GenServer.start_link(__MODULE__, options)
  end

  # def start_link( {scheme, host, port}) do
  #   GenServer.start_link(__MODULE__, {scheme, host, port})
  # end

  def forward(conn, extra_path, backend) do
    %{host: host, path: path, port: port, scheme: string_scheme} = URI.parse(backend)

    scheme =
      case string_scheme do
        "http" -> :http
        "https" -> :https
        _ -> :unknown
      end

    conn = Plug.Conn.assign(conn, :extra_path, extra_path)

    {:ok, pid} =
      ConnectionForwarder.start_link(%{scheme: scheme, host: host, port: port, base_path: path})

    {:ok, conn} = ConnectionForwarder.proxy(pid, conn)
    conn
  end

  def proxy(pid, conn) do
    IO.puts("Starting the proxy")
    GenServer.call(pid, {:proxy, conn})
  end

  # def request(pid, method, path, headers, body) do
  #   GenServer.call(pid, {:request, method, path, headers, body})
  # end

  ## Callbacks
  @impl true
  def init(%{scheme: scheme, host: host, port: port, base_path: _base_path} = options) do
    IO.puts("In init")

    {:ok, conn} =
      Mint.HTTP.connect(scheme, host, port)
      |> IO.inspect(label: "Response from connect")

    {:ok, Map.put(options, :backend_host_conn, conn)}
  end

  @impl true
  def handle_call({:proxy, frontend_conn}, from, state) do
    IO.inspect(state, label: "connection start state")

    %{base_path: base_path, backend_host_conn: backend_host_conn} = state

    extra_path = frontend_conn.assigns[:extra_path]
    IO.inspect(base_path, label: "Our base path")
    IO.inspect(extra_path, label: "Our extra path")

    full_path = base_path <> Enum.join(extra_path, "/")

    headers = []
    body = ""

    case Mint.HTTP.request(backend_host_conn, "GET", full_path, headers, body) do
      {:ok, backend_conn, request_ref} ->
        new_state =
          state
          |> Map.put(:backend_conn, backend_conn)
          |> Map.put(:frontend_conn, frontend_conn)
          |> Map.put(:request_ref, request_ref)
          |> Map.put(:from, from)
          |> Map.put(:headers_sent, false)

        {:noreply, new_state}

      {:error, _conn, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(message, %{backend_conn: backend_conn} = state) do
    case Mint.HTTP.stream(backend_conn, message) do
      :unknown ->
        IO.inspect( message, label: "Unknown message received" )
        {:noreply, state}

      error = {:error, _, _, _} ->
        IO.inspect( error, label: "HTTP stream error occurred" )
        {:noreply, state}

      {:ok, backend_conn, responses} ->
        new_state =
          state
          |> Map.put(:backend_conn, backend_conn)

        new_state =
          responses
          |> Enum.reduce(new_state, fn chunk, state ->
            chunk
            |> IO.inspect(label: "Processing chunk")
            |> process_chunk(state)
          end)

        {:noreply, new_state}
    end
  end

  defp process_chunk({:status, _, status_code}, state) do
    # %{frontend_conn: frontend_conn} = state
    # new_frontend_conn = Plug.Conn.put_status(frontend_conn, status_code)
    Map.put(state, :return_status, status_code)
  end

  defp process_chunk({:headers, _, headers}, state) do
    %{frontend_conn: frontend_conn} = state
    headers = [{"secret-be-here", "Here come mu.semte.ch powers"} | headers]
    new_frontend_conn = Plug.Conn.merge_resp_headers(frontend_conn, headers)
    Map.put(state, :frontend_conn, new_frontend_conn)
  end

  defp process_chunk(
         {:data, _, _} = message,
         %{headers_sent: false, return_status: return_status, frontend_conn: frontend_conn} =
           state
       ) do
    new_state =
      state
      |> Map.put(:frontend_conn, Plug.Conn.send_chunked(frontend_conn, return_status))
      |> Map.put(:headers_sent, true)

    process_chunk(message, new_state)
  end

  defp process_chunk({:data, _, new_data}, state) do
    %{frontend_conn: frontend_conn} = state

    case Plug.Conn.chunk(frontend_conn, new_data) do
      {:ok, new_frontend_conn} ->
        state
        |> Map.put(:frontend_conn, new_frontend_conn)

      {:error, :closed} ->
        IO.puts("Could not proxy body further, socket already closed")
        state
    end
  end

  defp process_chunk({:done, _}, %{from: from, frontend_conn: frontend_conn} = state) do
    GenServer.reply(from, {:ok, frontend_conn})

    # should this include backend_host_conn ?
    new_state =
      [:from, :request_ref, :headers_sent, :response_status]
      |> Enum.reduce(state, &Map.delete(&2, &1))

    new_state
  end

  defp process_chunk({:error, _, _} = message, state) do
    IO.inspect( message, label: "Error message occurred" )
    state
  end

  defp process_chunk(message, state) do
    IO.inspect( message, label: "Unprocessed message" )
    state
  end
end
