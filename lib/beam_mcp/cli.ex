defmodule BeamMcp.CLI do
  @moduledoc """
  Command-line interface for BeamMCP.
  
  Usage:
    beam-mcp stdio - Start stdio MCP server for Elixir execution
    beam-mcp cnode --name NAME --cookie COOKIE - Start cnode bridge
  """

  require Logger

  def main(args) do
    case args do
      ["stdio"] ->
        start_stdio_server()

      ["cnode", "--name", name, "--cookie", cookie] ->
        start_cnode_bridge(name, cookie)

      _ ->
        print_usage()
        System.halt(1)
    end
  end

  defp start_stdio_server do
    Logger.info("Starting BeamMCP Stdio MCP Server")

    {:ok, _} = BeamMcp.StdioMcpServer.start()

    # Keep server running
    Process.sleep(:infinity)
  end

  defp start_cnode_bridge(name, cookie) do
    Logger.info("Starting BeamMCP Cnode Bridge: #{name}")

    {:ok, _} =
      BeamMcp.CnodeBridge.start_bridge(
        cnode_name: name,
        cookie: cookie,
        mcp_name: "cnode_#{name}"
      )

    # Keep running
    Process.sleep(:infinity)
  end

  defp print_usage do
    IO.puts("""
    BeamMCP - MCP Bridge for Elixir Runtime

    Usage:
      beam-mcp stdio              Start stdio MCP server for Elixir code execution
      beam-mcp cnode --name NAME --cookie COOKIE
                                  Start cnode bridge to remote BEAM node

    Examples:
      # Start stdio server (exposes execute_elixir tool)
      beam-mcp stdio

      # Connect to remote cnode
      beam-mcp cnode --name erl_node --cookie secret_cookie
    """)
  end
end
