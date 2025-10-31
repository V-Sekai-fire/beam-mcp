defmodule BeamMcp.CnodeBridge.Server do
  @moduledoc """
  MCP Server that bridges requests to a remote cnode.
  
  This GenServer implements the ExMCP.Server behavior and forwards tool calls,
  resource reads, and prompt completions to the remote cnode.
  """

  use GenServer
  require Logger

  @doc """
  Start the MCP bridge server.
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  Stop the bridge server.
  """
  def stop(bridge_name) do
    GenServer.stop(via_tuple(bridge_name))
  end

  @doc """
  Call a tool on the remote cnode.
  """
  def call_tool(bridge_name, tool_name, arguments) do
    GenServer.call(via_tuple(bridge_name), {:call_tool, tool_name, arguments}, 5000)
  end

  @doc """
  List available tools on the remote cnode.
  """
  def list_tools(bridge_name) do
    GenServer.call(via_tuple(bridge_name), :list_tools, 5000)
  end

  @doc """
  Read a resource from the remote cnode.
  """
  def read_resource(bridge_name, resource_uri) do
    GenServer.call(via_tuple(bridge_name), {:read_resource, resource_uri}, 5000)
  end

  @impl true
  def init(opts) do
    cnode_name = Keyword.fetch!(opts, :cnode_name)
    mcp_name = Keyword.get(opts, :name, "cnode-bridge")
    tools = Keyword.get(opts, :tools, [])
    resources = Keyword.get(opts, :resources, [])
    prompts = Keyword.get(opts, :prompts, [])

    state = %{
      cnode_name: cnode_name,
      mcp_name: mcp_name,
      tools: tools,
      resources: resources,
      prompts: prompts,
      pending_requests: %{}
    }

    Logger.info("Started MCP bridge server: #{mcp_name} -> #{cnode_name}")
    {:ok, state}
  end

  @impl true
  def handle_call({:call_tool, tool_name, arguments}, _from, state) do
    case call_cnode(state.cnode_name, {:call_tool, tool_name, arguments}) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      :unavailable ->
        error = "Cnode #{state.cnode_name} is unavailable"
        Logger.error(error)
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call(:list_tools, _from, state) do
    case call_cnode(state.cnode_name, :list_tools) do
      {:ok, tools} ->
        {:reply, {:ok, tools}, state}

      :unavailable ->
        error = "Cnode #{state.cnode_name} is unavailable"
        Logger.error(error)
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:read_resource, resource_uri}, _from, state) do
    case call_cnode(state.cnode_name, {:read_resource, resource_uri}) do
      {:ok, content} ->
        {:reply, {:ok, content}, state}

      :unavailable ->
        error = "Cnode #{state.cnode_name} is unavailable"
        Logger.error(error)
        {:reply, {:error, error}, state}
    end
  end

  defp call_cnode(cnode_name, request) do
    node = String.to_atom("#{cnode_name}@localhost")

    try do
      case :rpc.call(node, BeamMcp.CnodeHandler, :handle_mcp_request, [request]) do
        {:badrpc, _reason} ->
          :unavailable

        result ->
          {:ok, result}
      end
    catch
      :exit, _reason ->
        :unavailable
    end
  end

  defp via_tuple(name) do
    {:via, Registry, {BeamMcp.Registry, name}}
  end
end
