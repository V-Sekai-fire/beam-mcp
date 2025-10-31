defmodule BeamMcp.CnodeHandler do
  @moduledoc """
  Behaviour module for handling MCP requests from a remote cnode.
  
  This module defines the interface that a cnode must implement to handle
  MCP requests routed through the bridge.
  """

  @callback handle_mcp_request(request :: term()) :: term()
end
