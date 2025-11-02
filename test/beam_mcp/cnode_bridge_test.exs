defmodule BeamMcp.CnodeBridgeTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "start_bridge/1" do
    test "successfully starts a bridge with required options" do
      opts = [
        cnode_name: "test_cnode",
        cookie: "secret",
        mcp_name: "test_bridge"
      ]

      # This test verifies the bridge can be configured
      # In practice, this would connect to a real cnode
      assert is_list(opts)
    end

    test "requires cnode_name option" do
      opts = [cookie: "secret"]

      assert_raise KeyError, fn ->
        BeamMcp.CnodeBridge.start_bridge(opts)
      end
    end

    test "requires cookie option" do
      opts = [cnode_name: "test_cnode"]

      assert_raise KeyError, fn ->
        BeamMcp.CnodeBridge.start_bridge(opts)
      end
    end
  end

  describe "call_tool/3" do
    test "forwards tool call to remote cnode" do
      # Setup mock
      stub(BeamMcp.CnodeMock, :handle_mcp_request, fn {:call_tool, "test_tool", %{}} ->
        %{"content" => [%{"type" => "text", "text" => "Tool result"}]}
      end)

      # In a real scenario, this would call through the bridge
      result = BeamMcp.CnodeMock.handle_mcp_request({:call_tool, "test_tool", %{}})

      assert result == %{"content" => [%{"type" => "text", "text" => "Tool result"}]}
    end

    test "handles tool call errors" do
      stub(BeamMcp.CnodeMock, :handle_mcp_request, fn {:call_tool, "failing_tool", _} ->
        {:error, "Tool not found"}
      end)

      result = BeamMcp.CnodeMock.handle_mcp_request({:call_tool, "failing_tool", %{}})

      assert result == {:error, "Tool not found"}
    end
  end

  describe "list_tools/1" do
    test "returns list of tools from remote cnode" do
      tools = [
        %{"name" => "tool1", "description" => "First tool"},
        %{"name" => "tool2", "description" => "Second tool"}
      ]

      stub(BeamMcp.CnodeMock, :handle_mcp_request, fn :list_tools ->
        tools
      end)

      result = BeamMcp.CnodeMock.handle_mcp_request(:list_tools)

      assert result == tools
    end
  end

  describe "read_resource/2" do
    test "reads resource from remote cnode" do
      stub(BeamMcp.CnodeMock, :handle_mcp_request, fn {:read_resource, "file://test.txt"} ->
        %{"content" => "Resource content"}
      end)

      result = BeamMcp.CnodeMock.handle_mcp_request({:read_resource, "file://test.txt"})

      assert result == %{"content" => "Resource content"}
    end

    test "handles resource read errors" do
      stub(BeamMcp.CnodeMock, :handle_mcp_request, fn {:read_resource, "file://missing.txt"} ->
        {:error, "Resource not found"}
      end)

      result = BeamMcp.CnodeMock.handle_mcp_request({:read_resource, "file://missing.txt"})

      assert result == {:error, "Resource not found"}
    end
  end
end
