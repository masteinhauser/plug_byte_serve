defmodule PlugByteServePathTest do
  use ExUnit.Case
  use Plug.Test

  defmodule PathPlug do
    import Plug.Conn
    use Plug.Router

    plug :match
    plug :dispatch

    # head "/" do
    match "/:file", via: :head do
      path = "test/files/"
      conn
      |> PlugByteServe.call([path: path, file: file])
      |> send_resp()
    end

    get "/:file" do
      path = "test/files/"
      conn
      |> PlugByteServe.call([path: path, file: file])
      |> send_resp()
    end
  end

  defp call(conn) do
    PathPlug.call(conn, [])
  end

  test "head response with only headers and webm" do
    conn = conn(:head, "/sample.webm") |> call
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["video/webm"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-length") == ["314042"]
    assert byte_size(conn.resp_body) == 0
  end

  test "get without range responds with some data" do
    conn = conn(:get, "/sample.mp4") |> call
    assert conn.status == 206
    assert get_resp_header(conn, "content-type") == ["video/mp4"]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-length") == ["1000"]
    assert byte_size(conn.resp_body) == 1000
  end
end
