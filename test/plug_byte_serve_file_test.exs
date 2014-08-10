defmodule PlugByteServePathFileTest do
  use ExUnit.Case
  use Plug.Test

  defmodule FilePlug do
    import Plug.Conn
    use Plug.Router

    plug PlugByteServe, path: "test/files/", file: "sample.mp4"
    plug :match
    plug :dispatch

    # head "/" do
    match "/", via: :head do
      conn
      |> send_resp()
    end

    get "/" do
      conn
      |> send_resp()
    end
  end

  defp call(conn) do
    FilePlug.call(conn, [])
  end

  test "head response with only headers" do
    conn = conn(:head, "/") |> call
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-length") == ["257546"]
    assert byte_size(conn.resp_body) == 0
  end

  test "get without range responds with some data" do
    conn = conn(:get, "/") |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-length") == ["1000"]
    assert byte_size(conn.resp_body) == 1000
  end

  test "get without range end responds with some data" do
    conn = conn(:get, "/")
            |> put_req_header("range", "bytes=0-")
            |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-range") == ["bytes 0-999/257546"]
    assert get_resp_header(conn, "content-length") == ["1000"]
    assert byte_size(conn.resp_body) == 1000
  end

  test "get larger range without end responds with rest of data" do
    conn = conn(:get, "/")
            |> put_req_header("range", "bytes=0-")
            |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-range") == ["bytes 0-999/257546"]
    assert get_resp_header(conn, "content-length") == ["1000"]
    assert byte_size(conn.resp_body) == 1000
  end

  test "get without range start responds with some data" do
    conn = conn(:get, "/")
            |> put_req_header("range", "bytes=-0")
            |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-range") == ["bytes 0-0/257546"]
    assert get_resp_header(conn, "content-length") == ["1"]
    assert byte_size(conn.resp_body) == 1
  end

  test "get with small range responds with small range data" do
    conn = conn(:get, "/")
            |> put_req_header("range", "bytes=0-1")
            |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-range") == ["bytes 0-1/257546"]
    assert get_resp_header(conn, "content-length") == ["2"]
    assert byte_size(conn.resp_body) == 2
  end

  test "get with medium range responds with medium range data" do
    conn = conn(:get, "/")
            |> put_req_header("range", "bytes=0-10239")
            |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-range") == ["bytes 0-10239/257546"]
    assert get_resp_header(conn, "content-length") == ["10240"]
    assert byte_size(conn.resp_body) == 10240
  end

  test "get with large range responds with large range data" do
    conn = conn(:get, "/")
            |> put_req_header("range", "bytes=0-257545")
            |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-range") == ["bytes 0-257545/257546"]
    assert get_resp_header(conn, "content-length") == ["257546"]
    assert byte_size(conn.resp_body) == 257546
  end

  test "get with invalid partial range responds with correct range and some data" do
    conn = conn(:get, "/")
            |> put_req_header("range", "bytes=257545-3000000")
            |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-range") == ["bytes 257545-257545/257546"]
    assert get_resp_header(conn, "content-length") == ["1"]
    assert byte_size(conn.resp_body) == 1
  end

  test "get with invalid total range responds with status 416, correct range and no data" do
    conn = conn(:get, "/")
            |> put_req_header("range", "bytes=257546-300000")
            |> call
    assert conn.status == 416
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-length") == ["257546"]
    assert byte_size(conn.resp_body) == 0
  end
end
