defmodule PlugByteServe do
  @moduledoc """
  A plug for streaming files with HTTP Byte Serving.

  ## Example

      defmodule GetServedApp do
        import Plug.Conn
        use Plug.Router

        plug PlugByteServe, path: "/tmp", file: "/tmp/file"
        plug :match
        plug :dispatch

        get "/bytes" do
          conn
          |> send_resp()
        end
      end

      #      defmodule GetServedApp do
      #        import Plug.Conn
      #        use Plug.Router
      #
      #        plug PlugByteServe
      #        plug :match
      #        plug :dispatch
      #
      #        get "/bytes" do
      #          dynamic_file_path = "/tmp/" <> "file"
      #
      #          conn
      #          |> PlugByteServe.call({file: dynamic_file_path})
      #          |> send_resp()
      #        end
      #      end
  """
  #  @behaviour Plug.Module

  alias Plug.Conn
  import Plug.Conn, only: [get_req_header:  2,
                            put_resp_header: 3,
                            resp:       3]

  def init(opts \\ []) do
    path = Keyword.get(opts, :path)
    file = Keyword.get(opts, :file)
    [path: path, file: file]
  end

  def call(%Conn{method: "HEAD"} = conn, opts) do
    file = get_file(opts)
    {:ok, file_info} = File.stat(file)

    content_type = Plug.MIME.path(file)
    conn
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("content-length", "#{file_info.size}")
    |> resp(200, "")
  end

  def call(%Conn{method: "GET"} = conn, opts) do
    file = get_file(opts)
    {:ok, file_info} = File.stat(file)

    {status, range_start, range_end, range_limit} = find_range(conn, file)

    {:ok, data} =
      case status do
        206 -> read_file(file, range_start, range_end, range_limit)
        416 -> {:ok, ""}
      end

    content_type = Plug.MIME.path(file)
    conn
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("content-length", "#{range_limit}")
    |> put_resp_header("content-range", "bytes #{range_start}-#{range_end}/#{file_info.size}")
    |> resp(status, data)
  end

  def call(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp get_file(opts) do
    path = Keyword.get(opts, :path, System.cwd)
    file = Keyword.fetch!(opts, :file)
    path <> "/" <> file
  end

  defp find_range(conn, file) do
    byte_limit = 1_000_000
    {:ok, file_info} = File.stat(file)

    hdr_range =
      case hdr_range = get_req_header(conn, "range") do
        [] -> []
        _  -> String.split(List.last(hdr_range), ["=", "-"])
      end

    [_range_type, range_start, range_end] =
      case hdr_range do
        ["bytes", "",          ""]        -> ["bytes", "0",         "999"]
        ["bytes", "0",         ""]        -> ["bytes", "0",         "999"]
        ["bytes", range_start, ""]        -> ["bytes", range_start, "#{file_info.size - 1}"]
        ["bytes", "",          range_end] -> ["bytes", "0",         range_end]
        ["bytes", range_start, range_end] -> ["bytes", range_start, range_end]
        _                                 -> ["bytes", "0",         "999"]
      end

    [range_start, range_end] = Enum.map([range_start, range_end], fn(x) -> String.to_integer(x) end)

    # Check range is within file
    {status, r_start, r_end} =
      cond do
        range_start >  range_end       -> {416, 0, file_info.size - 1}
        range_start >= file_info.size  -> {416, 0, file_info.size - 1}
        range_start <  0 and range_end >= file_info.size -> {416, 0, file_info.size - 1}
        range_start >= 0 and range_end <  file_info.size -> {206, range_start, range_end}
        range_start >= 0 and range_end >= file_info.size -> {206, range_start, file_info.size - 1}
        range_start <  0 and range_end <  file_info.size -> {206, 0, range_end}
      end

    # Limit the number of bytes read at once
    [r_start, r_end, r_limit] =
    cond do
      r_end - r_start + 1 > byte_limit ->
        # Make sure they are not too greedy
        [r_start, r_start + byte_limit, (r_start + byte_limit) - r_start + 1]
      r_end - r_start + 1 == 0 ->
        # Handle when they are asking for just 1 byte
        [r_start, r_end, 1]
      true ->
        # Normal request
        [r_start, r_end, r_end - r_start + 1]
    end

    {status, r_start, r_end, r_limit}
  end

  defp read_file(file, range_start, _range_end, range_limit) do
    {:ok, device} = :file.open(file, [:read, :binary])
    {:ok, _position} = :file.position(device, range_start)
    {:ok, data} = :file.read(device, range_limit)
    {:ok, data}
  end
end
