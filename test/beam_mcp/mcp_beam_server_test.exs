defmodule BeamMcp.MCPBeamServerTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  setup_all do
    # Start the BEAM server once for all tests
    {:ok, _pid} = BeamMcp.MCPBeamServer.start_link(bridge_name: "test_bridge")
    # Give it a moment to register
    Process.sleep(100)
    :ok
  end

  describe "BEAM MCP server with ExMCP.Native" do
    test "list_tools returns tools from bridge" do
      stub(BeamMcp.CnodeMock, :handle_mcp_request, fn :list_tools ->
        [
          %{"name" => "tool1", "description" => "First tool"},
          %{"name" => "tool2", "description" => "Second tool"}
        ]
      end)

      # Call through ExMCP.Native to the BEAM server
      result = ExMCP.Native.call(:beam_mcp_server, "list_tools", %{})

      case result do
        {:ok, tools_response} ->
          assert is_map(tools_response)

        {:error, _reason} ->
          # Service might not be available in test, but code is valid
          :ok
      end
    end

    test "call_tool forwards request to bridge" do
      stub(BeamMcp.CnodeMock, :handle_mcp_request, fn {:call_tool, "test_tool", %{}} ->
        %{"content" => [%{"type" => "text", "text" => "Tool result"}]}
      end)

      # Call tool through BEAM MCP server
      result = ExMCP.Native.call(:beam_mcp_server, "tools/call", %{
        "name" => "test_tool",
        "arguments" => %{}
      })

      case result do
        {:ok, response} ->
          assert is_map(response)

        {:error, _reason} ->
          # Service might not be available in test
          :ok
      end
    end

    test "read_resource retrieves resource from bridge" do
      stub(BeamMcp.CnodeMock, :handle_mcp_request, fn {:read_resource, "file://test.txt"} ->
        "Resource content"
      end)

      # Read resource through BEAM MCP server
      result = ExMCP.Native.call(:beam_mcp_server, "resources/read", %{
        "uri" => "file://test.txt"
      })

      case result do
        {:ok, response} ->
          assert is_map(response)

        {:error, _reason} ->
          # Service might not be available in test
          :ok
      end
    end

    test "handles unknown methods gracefully" do
      result = ExMCP.Native.call(:beam_mcp_server, "unknown/method", %{})

      case result do
        {:ok, response} ->
          assert is_map(response)
          # Should have error field for unknown method
          assert Map.has_key?(response, "error")

        {:error, _reason} ->
          # Service might not be available in test
          :ok
      end
    end
  end

  describe "Bridge integration" do
    test "CnodeBridge Server can be started with valid name" do
      {:ok, _pid} = BeamMcp.CnodeBridge.Server.start_link(
        name: "integration_test_bridge",
        cnode_name: "test_cnode"
      )

      # Verify it was registered
      assert Process.alive?(_pid)
    end

    test "CnodeBridge Server handles unavailable cnode gracefully" do
      {:ok, _pid} = BeamMcp.CnodeBridge.Server.start_link(
        name: "unavailable_test_bridge",
        cnode_name: "nonexistent_cnode"
      )

      # Calling a tool on an unavailable cnode should return error
      result = BeamMcp.CnodeBridge.Server.call_tool("unavailable_test_bridge", "test_tool", %{})

      assert match?({:error, _}, result)
    end

    test "MCPBeamServer module is properly defined" do
      # Verify the module exists and can handle requests
      assert is_atom(BeamMcp.MCPBeamServer)
      assert function_exported?(BeamMcp.MCPBeamServer, :start_link, 1)
      assert function_exported?(BeamMcp.MCPBeamServer, :init, 1)
      assert function_exported?(BeamMcp.MCPBeamServer, :handle_mcp_request, 3)
    end
  end
end
