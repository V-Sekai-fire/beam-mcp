defmodule BeamMcp.MCPBeamServer do
  @moduledoc """
  BEAM-native MCP server for testing the cnode bridge.
  
  This server exposes the cnode bridge through ExMCP's native BEAM transport,
  allowing direct in-memory testing without serialization overhead.
  """

  use ExMCP.Service, name: :beam_mcp_server

  require Logger

  @impl true
  def init(opts) do
    bridge_name = Keyword.get(opts, :bridge_name, "default_bridge")
    {:ok, %{bridge_name: bridge_name}}
  end

  @impl true
  def handle_mcp_request("list_tools", _params, state) do
    case BeamMcp.CnodeBridge.Server.list_tools(state.bridge_name) do
      {:ok, tools} ->
        {:ok, %{"tools" => tools}, state}

      {:error, reason} ->
        {:ok, %{"error" => inspect(reason)}, state}
    end
  end

  @impl true
  def handle_mcp_request("tools/call", %{"name" => tool_name, "arguments" => args}, state) do
    case BeamMcp.CnodeBridge.Server.call_tool(state.bridge_name, tool_name, args) do
      {:ok, result} ->
        {:ok, %{"content" => result}, state}

      {:error, reason} ->
        {:ok, %{"error" => inspect(reason)}, state}
    end
  end

  @impl true
  def handle_mcp_request("resources/read", %{"uri" => uri}, state) do
    case BeamMcp.CnodeBridge.Server.read_resource(state.bridge_name, uri) do
      {:ok, content} ->
        {:ok, %{"content" => content}, state}

      {:error, reason} ->
        {:ok, %{"error" => inspect(reason)}, state}
    end
  end

  @impl true
  def handle_mcp_request(method, params, state) do
    Logger.warning("Unhandled MCP request: #{method} with params: #{inspect(params)}")
    {:ok, %{"error" => "Unknown method: #{method}"}, state}
  end
end
