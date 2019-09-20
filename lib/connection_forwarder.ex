defmodule ConnectionForwarder do
  use GenServer

  require Logger

  @type connection_spec :: {:http | :https, String.t(), integer}
  @type backend_string_info :: {:http | :https, String.t(), integer, String.t()}

  @spec start_link(connection_spec) :: {:ok, pid()} | {:error, any}
  def start_link(connection_spec) do
    GenServer.start_link(__MODULE__, connection_spec)
  end

  @spec start(connection_spec) :: {:ok, pid()} | {:error, any}
  def start(connection_spec) do
    GenServer.start(__MODULE__, connection_spec)
  end

  @spec extract_info_from_backend_string(String.t()) :: backend_string_info
  def extract_info_from_backend_string(backend_string) do
    %{host: host, path: base_path, port: port, scheme: string_scheme} = URI.parse(backend_string)

    scheme =
      case string_scheme do
        "http" -> :http
        "https" -> :https
        _ -> :unknown
      end

    base_path = base_path || "/"

    {scheme, host, port, base_path}
  end

  @spec forward(
          Plug.Conn.t(),
          [String.t()],
          String.t() | backend_string_info,
          ProxyManipulatorSettings.t()
        ) :: Plug.Conn.t() | {:error, any()}
  def forward(frontend_conn, extra_path, backend_string, manipulators)
      when is_binary(backend_string) do
    backend_string_info = extract_info_from_backend_string(backend_string)
    forward(frontend_conn, extra_path, backend_string_info, manipulators)
  end

  def forward(frontend_conn, extra_path, {scheme, host, port, base_path}, manipulators) do
    frontend_conn =
      frontend_conn
      |> Plug.Conn.assign(:extra_path, extra_path)
      |> Plug.Conn.assign(:base_path, base_path)

    # case ConnectionForwarder.start_link({scheme, host, port}) do
    connection_spec = {scheme, host, port}

    case ConnectionPool.get_connection(connection_spec) do
      {:ok, pid} ->
        case ConnectionForwarder.proxy(pid, frontend_conn, manipulators) do
          {:ok, conn} ->
            conn

          {:error, _} ->
            # ignore the old connection and try with a fresh connection

            # TODO: kill the old connection process (no need to remove
            # it, it's not in the pool)
            case ConnectionPool.get_new_connection(connection_spec) do
              {:error, reason} ->
                IO.inspect({:error, reason}, label: "An error occurred")
                frontend_conn

              {:ok, pid} ->
                case ConnectionForwarder.proxy(pid, frontend_conn, manipulators) do
                  {:ok, conn} ->
                    conn

                  {:error, reason} ->
                    IO.inspect({:error, reason}, label: "An error occurred")
                    frontend_conn
                end
            end
        end

      {:error, reason} ->
        IO.inspect({:error, reason}, label: "An error occurred")
        frontend_conn
    end
  end

  def proxy(pid, conn, manipulators) do
    GenServer.call(pid, {:proxy, conn, manipulators})
  end

  ## Callbacks
  @impl true
  def init({scheme, host, port} = connection_spec) do
    {:ok, conn} = Mint.HTTP.connect(scheme, host, port)
    {:ok, %{backend_host_conn: conn, connection_spec: connection_spec}}
  end

  @impl true
  def handle_call({:proxy, frontend_conn, manipulators}, from, state) do
    %{backend_host_conn: backend_host_conn} = state

    state = Map.put(state, :manipulators, manipulators)

    extra_path = frontend_conn.assigns[:extra_path]
    base_path = frontend_conn.assigns[:base_path]
    full_path = base_path <> Enum.join(extra_path, "/")

    # TODO: get actual headers and pass them along
    # {{frontend_conn, backend_host_conn}, headers} =
    {headers, {frontend_conn, backend_host_conn}} =
      Map.get( frontend_conn, :req_headers )
      |> ProxyManipulatorSettings.process_request_headers(
        manipulators,
        {frontend_conn, backend_host_conn}
      )

    {:done, body, frontend_conn, backend_host_conn} =
      get_full_plug_request_body(frontend_conn)
      |> manipulate_full_plug_request_body(manipulators, backend_host_conn)

    method = Map.get(frontend_conn, :method)

    case Mint.HTTP.request(backend_host_conn, method, full_path, headers, body) do
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
        IO.inspect(message, label: "Unknown message received")
        {:noreply, state}

      error = {:error, _, _, _} ->
        IO.inspect(error, label: "HTTP stream error occurred")
        # TODO: kill the connection PID
        ConnectionPool.remove_connection(Map.get(state, :connection_spec), self())
        {:noreply, state}

      {:ok, backend_conn, responses} ->
        new_state =
          state
          |> Map.put(:backend_conn, backend_conn)

        new_state =
          responses
          |> Enum.reduce(new_state, fn chunk, state ->
            # IO.inspect(elem(chunk, 0), label: "Processing chunk type")
            process_chunk(chunk, state)
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
    %{frontend_conn: frontend_conn, backend_conn: backend_conn, manipulators: manipulators} =
      state

    {headers, {backend_conn, frontend_conn}} =
      ProxyManipulatorSettings.process_response_headers(
        headers,
        manipulators,
        {frontend_conn, backend_conn}
      )

    headers = [{"secret-be-here", "Here come mu.semte.ch powers"} | headers]
    frontend_conn = Map.put( frontend_conn, :resp_headers, headers )

    state
    |> Map.put(:frontend_conn, frontend_conn)
    |> Map.put(:backend_conn, backend_conn)
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
    %{frontend_conn: frontend_conn, backend_conn: backend_conn, manipulators: manipulators} =
      state

    {new_data, {backend_conn, frontend_conn}} =
      ProxyManipulatorSettings.process_response_chunk(
        new_data,
        manipulators,
        {frontend_conn, backend_conn}
      )

    state =
      state
      |> Map.put(:frontend_conn, frontend_conn)
      |> Map.put(:backend_conn, backend_conn)

    case Plug.Conn.chunk(frontend_conn, new_data) do
      {:ok, new_frontend_conn} ->
        state
        |> Map.put(:frontend_conn, new_frontend_conn)

      {:error, :closed} ->
        IO.puts("Could not proxy body further, socket already closed")
        state
    end
  end

  defp process_chunk(
         {:done, _},
         %{
           from: from,
           frontend_conn: frontend_conn,
           connection_spec: connection_spec,
           backend_conn: backend_conn,
           manipulators: manipulators
         } = state
       ) do
    {_, {frontend_conn, backend_conn}} =
      ProxyManipulatorSettings.process_response_finish(
        true,
        manipulators,
        {frontend_conn, backend_conn}
      )

    GenServer.reply(from, {:ok, frontend_conn})

    # should this include backend_host_conn ?
    new_state =
      [:from, :request_ref, :headers_sent, :response_status]
      |> Enum.reduce(state, &Map.delete(&2, &1))
      |> Map.put(:frontend_conn, frontend_conn)
      |> Map.put(:backend_conn, backend_conn)

    ConnectionPool.return_connection(connection_spec, self())

    new_state
  end

  defp process_chunk({:error, _, _} = message, state) do
    IO.inspect(message, label: "Error message occurred")
    state
  end

  defp process_chunk(message, state) do
    IO.inspect(elem(message, 0), label: "Unprocessed message of type")
    state
  end

  defp get_full_plug_request_body(conn, body \\ "") do
    case Plug.Conn.read_body(conn) do
      {:ok, stuff, conn} ->
        {:done, body <> stuff, conn}

      {:more, stuff, conn} ->
        get_full_plug_request_body(conn, body <> stuff)

      {:error, reason} ->
        {:error, conn, reason}
    end
  end

  defp manipulate_full_plug_request_body(
         {:error, frontend_conn, reason},
         _manipulators,
         _backend_conn
       ) do
    {:error, frontend_conn, reason}
  end

  defp manipulate_full_plug_request_body({:done, body, frontend_conn}, manipulators, backend_conn) do
    {body,{frontend_conn, backend_conn}} =
      ProxyManipulatorSettings.process_request_chunk(
        body,
        manipulators,
        {frontend_conn, backend_conn}
      )

    {_, {frontend_conn, backend_conn}} =
      ProxyManipulatorSettings.process_request_finish(
        true,
        manipulators,
        {frontend_conn, backend_conn}
      )

    {:done, body, frontend_conn, backend_conn}
  end
end
