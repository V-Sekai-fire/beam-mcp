defmodule BeamMcp.ElixirExecutor do
  @moduledoc """
  Safe Elixir code execution with timeout and error handling.
  
  Executes Elixir code on the local node with:
  - Timeout protection (default 5 seconds)
  - Exception isolation
  - Audit logging
  - Structured error responses
  """

  require Logger

  @default_timeout 5000

  @doc """
  Execute Elixir code safely with timeout.
  
  Returns:
    {:ok, %{"result" => result}} on success
    {:error, %{"error" => reason, "type" => error_type}} on failure
  """
  def execute(code, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    bindings = Keyword.get(opts, :bindings, [])

    Logger.info("Executing Elixir code (timeout: #{timeout}ms)")

    try do
      result =
        Task.async(fn ->
          Code.eval_string(code, bindings)
        end)
        |> Task.await(timeout)

      handle_result(result)
    rescue
      e in CompileError ->
        Logger.error("Elixir compilation error: #{e.description}")
        {:error, %{"error" => e.description, "type" => "compile_error"}}

      e in ArithmeticError ->
        Logger.error("Elixir arithmetic error: #{inspect(e)}")
        {:error, %{"error" => inspect(e), "type" => "exception"}}

      e ->
        Logger.error("Elixir execution exception: #{inspect(e)}")
        {:error, %{"error" => inspect(e), "type" => "exception"}}
    catch
      :exit, {:timeout, _} ->
        Logger.error("Elixir execution timeout after #{timeout}ms")
        {:error, %{"error" => "Execution timeout", "type" => "timeout"}}

      :exit, {{error_type, error_value}, _stacktrace} when error_type in [ArithmeticError, RuntimeError] ->
        Logger.error("Elixir task error: #{inspect(error_type)} - #{inspect(error_value)}")
        {:error, %{"error" => inspect(error_value), "type" => "exception"}}

      :exit, reason ->
        Logger.error("Elixir task exit: #{inspect(reason)}")
        {:error, %{"error" => inspect(reason), "type" => "exception"}}

      e ->
        Logger.error("Elixir execution catch: #{inspect(e)}")
        {:error, %{"error" => inspect(e), "type" => "exception"}}
    end
  end

  defp handle_result({result, _bindings}) do
    {:ok, %{"result" => result}}
  end
end
