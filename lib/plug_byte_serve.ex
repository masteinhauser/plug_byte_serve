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

  @byte_limit 100_000_000 # 100 MB

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
      r_end - r_start + 1 == 0 ->
        # Handle when they are asking for just 1 byte
        [r_start, r_end, 1]
      true ->
        # Normal request
        [r_start, r_end, r_end - r_start + 1]
    end

    {status, r_start, r_end, r_limit}
  end

  defp read_file(file, range_start, range_end, range_limit) do
    # Limit the number of bytes read at once
    [rstart, rend, rlimit] =
    cond do
      range_end - range_start + 1 > @byte_limit ->
        # Make sure they are not too greedy
        [range_start, range_start + @byte_limit, (range_start + @byte_limit) - range_start + 1]
      range_end - range_start + 1 == 0 ->
        # Handle when they are asking for just 1 byte
        [range_start, range_end, 1]
      true ->
        # Normal request
        [range_start, range_end, range_end - range_start + 1]
    end

    served = 0
    read_ahead_limit = div(@byte_limit, 2)
    {:ok, device} = :file.open(file, [:read, :binary, {:read_ahead, read_ahead_limit}])
    do_read(rstart, rend, device, 0)
  end

  defp do_read(rstart, rend, device, acc) when rstart < rend do
    next_range = limit(rend - rstart, @byte_limit)
    {:ok, chunk} = :file.pread(device, rstart, next_range)
    do_read(next_range + 1, rend, device,  [chunk | acc])
  end

  defp do_read(_rstart, _rend, _device, acc) do
    Enum.reverse(acc) |> Enum.join
  end

  defp limit(range_limit, max_sys_limit) when range_limit <= max_sys_limit do
    range_limit
  end
  defp limit(_range_limit, max_sys_limit), do: max_sys_limit
end
