defmodule KVstore.Storage do
  @compile {:parse_transform, :ms_transform}
  require Logger
  use GenServer

  @moduledoc """
  The Storage reads and writes key-value pairs from/to dets.
  """

  alias :dets, as: Dets
  @table :kvstorage
  @cleanup_interval 30 * 60 * 1000 # cleanup time interval in milliseconds (30 mins)

  @doc """
  Opens storage file
  """
  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets value by key.
  Returns value or nil if keys is not found or expired.
  ## Examples
    iex> KVstore.Storage.set("key1", "value1", 1)
    :ok
    iex> KVstore.Storage.get("key1")
    "value1"

    iex> KVstore.Storage.get("unknown")
    nil

    iex> KVstore.Storage.set("key1", "value1", -1)
    :ok
    iex> KVstore.Storage.get("key1")
    nil
  """
  def get(key) do
    case Dets.lookup(@table, key) |> List.first() do
      {_, value, expiration} ->
        if expiration < :os.system_time(:seconds) do
          nil
        else
          value
        end
      _ -> nil
    end
  end

  @doc """
  Sets key-value pair with ttl in seconds
  ## Examples
    iex> KVstore.Storage.set("key1", "value1", 1)
    :ok
    iex> KVstore.Storage.get("key1")
    "value1"
  """
  def set(key, value, ttl) do
    Dets.insert(@table, {key, value, :os.system_time(:seconds) + ttl})
    Dets.sync(@table)
  end

  @doc """
  Deletes key from storage
  ## Examples
    iex> KVstore.Storage.set("key1", "value1", 100)
    :ok
    iex> KVstore.Storage.get("key1")
    "value1"
    iex> KVstore.Storage.delete("key1")
    :ok
    iex> KVstore.Storage.get("key1")
    nil
  """
  def delete(key) do
    Dets.delete(@table, key)
    Dets.sync(@table)
  end

  @doc """
  Manually cleans up expired keys
  ## Examples
    iex> KVstore.Storage.set("key1", "value1", -1)
    :ok
    iex> :dets.lookup(:kvstorage, "key1") |> length()
    1
    iex> KVstore.Storage.cleanup_manually()
    iex> :dets.lookup(:kvstorage, "key1") |> length()
    0
  """
  def cleanup_manually() do
    GenServer.call(__MODULE__, :cleanup_manually)
  end

  def init(_state) do
    Dets.open_file(@table, [type: :set])

    timer = schedule_cleanup()

    {:ok, %{timer: timer}}
  end

  @doc """
  Manual cleanup handler
  """
  def handle_call(:cleanup_manually, _from, %{timer: timer} = state) do
    # we should cancel automatic cleanup first
    Process.cancel_timer(timer)

    cleanup_expired()

    # then schedule the new one
    timer = schedule_cleanup()
    new_state = Map.put(state, :timer, timer)

    {:reply, new_state, new_state}
  end 

  @doc """
  Callback to cleanup expired keys
  """
  def handle_info(:cleanup, state) do
    cleanup_expired()

    timer = schedule_cleanup()
    new_state = Map.put(state, :timer, timer)

    {:noreply, new_state}
  end

  defp cleanup_expired() do
    time = :os.system_time(:seconds)
    Logger.info("Deleting expired keys at #{time}...")

    # select all expired keys at current_time
    keys = Dets.select(@table, [{{:"$1", :_, :"$3"}, [{:<, :"$3", time}], [:"$1"]}])
    
    Logger.info("Found #{length(keys)} to be deleted")

    # delete each key one by one
    Enum.each(keys, fn key -> Dets.delete(@table, key) end)
    Dets.sync(@table)
  end

  defp schedule_cleanup() do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
