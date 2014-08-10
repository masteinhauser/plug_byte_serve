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

  alias Plug.Conn
  import Plug.Conn, only: [get_req_header:  2,
                           send_resp:       3,
                           resp:       3,
                           put_resp_header: 3,
                           send_file:       5]

  def init(opts \\ []) do
    path = Keyword.get(opts, :path)
    file = Keyword.get(opts, :file)
    limit = Keyword.get(opts, :limit)
    [path: path, file: file, limit: limit]
  end

  def call(%Conn{method: "HEAD"} = conn, opts) do
    [path: _path, file: file, limit: _limit] =  get_opts(opts)
    {:ok, file_info} = get_file_info(opts)

    content_type = Plug.MIME.path(file)

    conn
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("content-length", "#{file_info.size}")
    |> resp(200, "")
  end

  def call(%Conn{method: "GET"} = conn, opts) do
    conn
    |> find_range(opts)
    |> send_f(opts)
  end

  def call(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp get_opts(opts) do
    path = Keyword.get(opts, :path, System.cwd)
    file = Keyword.fetch!(opts, :file)
    limit = Keyword.get(opts, :limit)
    [path: path, file: file, limit: limit]
  end

  defp get_file(opts) do
    [path: path, file: file, limit: _] =  get_opts(opts)
    path <> "/" <> file
  end

  defp get_file_info(opts) do
    opts
    |> get_opts
    |> get_file
    |> File.stat
  end

  defp find_range(conn, opts) do
    [path: _, file: _, limit: limit] =  get_opts(opts)
    {:ok, file_info} = get_file_info(opts)

    hdr_range =
      case hdr_range = get_req_header(conn, "range") do
        [] -> []
        _  -> String.split(List.last(hdr_range), ["=", "-"])
      end

    [_range_type, range_start, range_end] =
      case hdr_range do
        ["bytes", range_start, ""]        -> ["bytes", range_start, "#{file_info.size - 1}"]
        ["bytes", "",          range_end] -> ["bytes", "0",         range_end]
        ["bytes", range_start, range_end] -> ["bytes", range_start, range_end]
        _                                 -> ["bytes", "0",         "#{file_info.size - 1}"]
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

    limit =
    case limit do
      nil -> file_info.size
      _   -> limit
    end

    r_limit = r_end - r_start + 1
    r_limit =
      cond do
        r_limit > limit -> limit
        true -> r_limit
      end

    {conn, status, r_start, r_end, r_limit}
  end

  defp send_f({conn, status, range_start, range_end, range_limit}, opts) do
    file = get_file(opts)
    {:ok, file_info} = get_file_info(opts)

    content_type = Plug.MIME.path(file)
    conn
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("content-length", "#{range_limit}")
    |> put_resp_header("content-range", "bytes #{range_start}-#{range_end}/#{file_info.size}")
    |> send_status(status, file, range_start, range_limit)
  end

  defp send_status(conn, 206, file, range_start, range_limit) do
    send_file(conn, 206, file, range_start, range_limit)
  end
  defp send_status(conn, 416, _file, _range_start, _range_limit) do
    resp(conn, 416, "")
  end
end
