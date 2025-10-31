defmodule BeamMcp.CnodeBridge do
  @moduledoc """
  Bridge between MCP (Model Context Protocol) and Erlang cnodes.
  
  This module provides integration between ExMCP servers and distributed Erlang cnodes,
  allowing MCP clients to interact with Erlang-based services through a unified interface.
  """

  require Logger

  @doc """
  Start an MCP server that bridges to a remote cnode.
  
  ## Options
    * `:cnode_name` - Name of the cnode to connect to (required)
    * `:cnode_host` - Hostname of the cnode (default: "localhost")
    * `:cookie` - Erlang cookie for cluster authentication (required)
    * `:mcp_name` - Name of the MCP server (default: "cnode-bridge")
    * `:tools` - List of tools to expose via MCP (default: [])
    * `:resources` - List of resources to expose via MCP (default: [])
  """
  def start_bridge(opts) do
    cnode_name = Keyword.fetch!(opts, :cnode_name)
    cookie = Keyword.fetch!(opts, :cookie)
    cnode_host = Keyword.get(opts, :cnode_host, "localhost")
    mcp_name = Keyword.get(opts, :mcp_name, "cnode-bridge")

    with :ok <- set_cookie(cookie),
         :ok <- connect_cnode(cnode_name, cnode_host),
         {:ok, _pid} <- start_mcp_server(mcp_name, cnode_name, opts) do
      {:ok, {cnode_name, mcp_name}}
    else
      error -> {:error, error}
    end
  end

  @doc """
  Stop an MCP-cnode bridge.
  """
  def stop_bridge(bridge_info) do
    {_cnode_name, mcp_name} = bridge_info
    BeamMcp.CnodeBridge.Server.stop(mcp_name)
  end

  defp set_cookie(cookie) do
    case Node.set_cookie(String.to_atom(cookie)) do
      true -> :ok
      false -> {:error, "Failed to set cookie"}
    end
  end

  defp connect_cnode(cnode_name, cnode_host) do
    node = String.to_atom("#{cnode_name}@#{cnode_host}")

    case Node.connect(node) do
      true ->
        Logger.info("Connected to cnode: #{inspect(node)}")
        :ok

      false ->
        error = "Failed to connect to cnode: #{inspect(node)}"
        Logger.error(error)
        {:error, error}

      :ignored ->
        error = "Connection to cnode ignored: #{inspect(node)}"
        Logger.error(error)
        {:error, error}
    end
  end

  defp start_mcp_server(mcp_name, cnode_name, opts) do
    BeamMcp.CnodeBridge.Server.start_link(
      name: mcp_name,
      cnode_name: cnode_name,
      tools: Keyword.get(opts, :tools, []),
      resources: Keyword.get(opts, :resources, []),
      prompts: Keyword.get(opts, :prompts, [])
    )
  end

  @doc """
  Call a tool on the remote cnode through MCP.
  """
  def call_tool(bridge_name, tool_name, arguments) do
    case BeamMcp.CnodeBridge.Server.call_tool(bridge_name, tool_name, arguments) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List available tools on the remote cnode.
  """
  def list_tools(bridge_name) do
    BeamMcp.CnodeBridge.Server.list_tools(bridge_name)
  end

  @doc """
  Get a resource from the remote cnode.
  """
  def read_resource(bridge_name, resource_uri) do
    BeamMcp.CnodeBridge.Server.read_resource(bridge_name, resource_uri)
  end
end
