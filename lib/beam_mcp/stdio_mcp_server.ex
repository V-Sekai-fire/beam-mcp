defmodule BeamMcp.StdioMcpServer do
  @moduledoc """
  MCP Server over stdio transport for Elixir code execution.
  
  Exposes runtime Elixir execution capabilities via MCP stdio protocol.
  Clients can send code snippets and get back results.
  """

  require Logger

  @doc """
  Start the stdio MCP server.
  
  This blocks and handles stdio communication with MCP clients.
  """
  def start do
    Logger.info("Starting BeamMCP Stdio MCP Server")

    # Start the application supervision tree
    {:ok, _pid} = Application.ensure_all_started(:beam_mcp)

    # Run ExMCP server over stdio
    ExMCP.Server.start_link(
      transport: :stdio,
      handler: __MODULE__
    )
  end

  # ExMCP.Server callbacks

  @impl true
  def init(_args) do
    Logger.info("Initializing BeamMCP stdio MCP server")
    {:ok, %{}}
  end

  @impl true
  def handle_initialize(_params, state) do
    {:ok,
     %{
       "name" => "beam-mcp",
       "version" => "0.1.0",
       "capabilities" => %{
         "tools" => %{},
         "resources" => %{}
       }
     }, state}
  end

  @impl true
  def handle_list_tools(state) do
    tools = [
      %{
        "name" => "execute_elixir",
        "description" => "Execute arbitrary Elixir code on the remote BEAM node",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{
            "code" => %{
              "type" => "string",
              "description" => "Elixir code to execute"
            },
            "timeout" => %{
              "type" => "integer",
              "description" => "Execution timeout in milliseconds (default 5000)",
              "default" => 5000
            }
          },
          "required" => ["code"]
        }
      }
    ]

    {:ok, tools, state}
  end

  @impl true
  def handle_call_tool("execute_elixir", arguments, state) do
    code = Map.get(arguments, "code", "")
    timeout = Map.get(arguments, "timeout", 5000)

    Logger.info("Executing Elixir code via stdio: #{String.slice(code, 0, 50)}...")

    case BeamMcp.ElixirExecutor.execute(code, timeout: timeout) do
      {:ok, result} ->
        content = [
          %{
            "type" => "text",
            "text" => "Result: #{result["result"]}"
          }
        ]

        {:ok, content, state}

      {:error, error} ->
        content = [
          %{
            "type" => "text",
            "text" => "Error (#{error["type"]}): #{error["error"]}"
          }
        ]

        {:ok, content, state}
    end
  end

  @impl true
  def handle_call_tool(tool_name, _arguments, state) do
    Logger.warning("Unknown tool: #{tool_name}")
    {:ok, [%{"type" => "text", "text" => "Unknown tool: #{tool_name}"}], state}
  end

  @impl true
  def handle_list_resources(state) do
    {:ok, [], state}
  end

  @impl true
  def handle_read_resource(_uri, state) do
    {:ok, [%{"type" => "text", "text" => "Resource not found"}], state}
  end
end
