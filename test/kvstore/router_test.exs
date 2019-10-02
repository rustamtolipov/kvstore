defmodule KVstore.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias KVstore.Router
  alias KVstore.Storage

  @opts Router.init([])

  describe "get" do
    setup [:add_key]

    test "returns 404 if key doesn't exist" do
      conn = conn(:get, "/unknown")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 404
    end
  
    test "returns 200 and value if key exists" do
      conn = conn(:get, "/key1")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "value1"
    end  
  end  

  describe "post" do
    test "creates key" do
      conn = conn(:post, "/", "key=key2&value=value2&ttl=4")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 201
      assert conn.resp_body == "created"
    end

    test "returns 422 if ttl is not integer" do
      conn = conn(:post, "/", "key=key2&value=value2&ttl=abc")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 422
      assert conn.resp_body == "wrong ttl"
    end

    test "returns 422 if params wrong" do
      conn = conn(:post, "/", "blabla=bla")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 422
      assert conn.resp_body == "wrong params"
    end
  end

  describe "put" do
    setup [:add_key]

    test "returns 201" do
      conn = conn(:put, "/key1", "value=value2&ttl=4")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 201
      assert conn.resp_body == "created"
    end

    test "returns 422 if ttl is not integer" do
      conn = conn(:put, "/key1", "value=value2&ttl=abc")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 422
      assert conn.resp_body == "wrong ttl"
    end

    test "returns 422 if params wrong" do
      conn = conn(:put, "/key1", "blabla=bla")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 422
      assert conn.resp_body == "wrong params"
    end
  end

  describe "delete" do
    setup [:add_key]

    test "returns 204" do
      conn = conn(:delete, "/key1")
      |> Router.call(@opts)
  
      assert conn.state == :sent
      assert conn.status == 204
      assert conn.resp_body == "no content"
    end
  end
  
  defp add_key(_) do
    Storage.set("key1", "value1", 2)
  end
end