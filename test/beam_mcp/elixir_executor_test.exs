defmodule BeamMcp.ElixirExecutorTest do
  use ExUnit.Case

  describe "execute/2" do
    test "executes simple arithmetic" do
      {:ok, result} = BeamMcp.ElixirExecutor.execute("1 + 2")
      assert result["result"] == 3
    end

    test "executes string operations" do
      {:ok, result} = BeamMcp.ElixirExecutor.execute("\"hello\" <> \" world\"")
      assert result["result"] == "hello world"
    end

    test "executes list operations" do
      {:ok, result} = BeamMcp.ElixirExecutor.execute("[1, 2, 3] |> Enum.sum()")
      assert result["result"] == 6
    end

    test "handles nil return" do
      {:ok, result} = BeamMcp.ElixirExecutor.execute("nil")
      assert result["result"] == nil
    end

    test "handles boolean returns" do
      {:ok, result} = BeamMcp.ElixirExecutor.execute("true")
      assert result["result"] == true

      {:ok, result} = BeamMcp.ElixirExecutor.execute("false")
      assert result["result"] == false
    end

    test "catches compilation errors" do
      {:error, error} = BeamMcp.ElixirExecutor.execute("invalid @@@ syntax")
      assert error["type"] == "compile_error"
      assert is_binary(error["error"])
    end

    test "catches runtime errors" do
      {:error, error} = BeamMcp.ElixirExecutor.execute("1 / 0")
      assert error["type"] == "exception"
    end

    test "enforces timeout" do
      {:error, error} = BeamMcp.ElixirExecutor.execute("Process.sleep(10000)", timeout: 100)
      assert error["type"] == "timeout"
    end

    test "executes with custom timeout" do
      {:ok, result} = BeamMcp.ElixirExecutor.execute("Process.sleep(100); 42", timeout: 5000)
      assert result["result"] == 42
    end
  end
end
