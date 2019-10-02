defmodule KVstore.Router do
  use Plug.Router
  require Logger
  alias KVstore.Storage

  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug :match
  plug :dispatch

  get "/:key" do
    case Storage.get(key) do
      nil -> send_resp(conn, 404, "not found")
      value -> send_resp(conn, 200, value)
    end
  end

  # adds key-value pair if key, value and ttl are passed and ttl can be parsed to integer
  post "/", do: create_or_update(conn.params, conn)

  # update value and ttl for the given key
  put "/:key", do: Map.put(conn.params, "key", key) |> create_or_update(conn)

  delete "/:key" do 
    Storage.delete(key)
    send_resp(conn, 204, "no content")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp create_or_update(%{"key" => key, "value" => value, "ttl" => ttl}, conn) do
    case Integer.parse(ttl) do
      {ttl_int, _} -> 
        Storage.set(key, value, ttl_int)
        send_resp(conn, 201, "created")
      _ -> send_resp(conn, 422, "wrong ttl")
    end
  end
  
  defp create_or_update(_, conn) do
    Logger.info("params #{conn.params |> Map.keys |> Enum.join(",")}")
    send_resp(conn, 422, "wrong params")
  end
end
