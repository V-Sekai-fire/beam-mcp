defmodule BeamMcp.Discovery do
  @moduledoc """
  Dynamic discovery of modules and functions on remote BEAM node.
  
  Enumerates all loaded modules, inspects their exported functions,
  and generates MCP tool definitions for remote function calls.
  """

  require Logger

  @doc """
  Discover all tools on a remote cnode.
  
  Returns list of MCP tool definitions for functions on the remote node.
  """
  def discover_tools(cnode_name) do
    node = String.to_atom("#{cnode_name}@localhost")

    try do
      # Get all loaded modules
      case :rpc.call(node, :code, :all_loaded, []) do
        modules when is_list(modules) ->
          modules
          |> Enum.filter(&user_module?/1)
          |> Enum.flat_map(&extract_functions/1)
          |> Enum.map(&to_tool_definition/1)

        {:badrpc, _reason} ->
          Logger.error("Failed to discover modules on #{node}")
          []
      end
    catch
      :exit, _reason ->
        Logger.error("Node #{node} unreachable during discovery")
        []
    end
  end

  defp user_module?({module, _}) do
    module_name = Atom.to_string(module)

    # Filter out OTP and system modules
    not String.starts_with?(module_name, "erl_") and
      not String.starts_with?(module_name, "sys_") and
      not String.starts_with?(module_name, "code_") and
      not String.starts_with?(module_name, "application") and
      module_name != "kernel" and
      module_name != "stdlib"
  end

  defp extract_functions({module, _beam_path}) do
    try do
      case :code.get_doc(module) do
        {:docs_v1, _anno, _lang, _format, module_doc, _metadata, docs} ->
          docs
          |> Enum.filter(&is_function_doc?/1)
          |> Enum.map(&doc_to_function_info(module, &1))

        _ ->
          # Fallback: get exports
          module.module_info(:exports)
          |> Enum.map(fn {name, arity} -> {module, name, arity, nil} end)
      end
    catch
      :error, _reason ->
        # If doc retrieval fails, use module_info
        try do
          module.module_info(:exports)
          |> Enum.map(fn {name, arity} -> {module, name, arity, nil} end)
        catch
          :error, _ -> []
        end
    end
  end

  defp is_function_doc?({:function, {_name, _arity}, _anno, _sig, _doc}), do: true
  defp is_function_doc?(_), do: false

  defp doc_to_function_info(module, {:function, {name, arity}, _anno, _sig, doc}) do
    description =
      case doc do
        :hidden -> "#{name}/#{arity}"
        doc_content when is_binary(doc_content) -> String.slice(doc_content, 0, 100)
        _ -> "#{name}/#{arity}"
      end

    {module, name, arity, description}
  end

  defp to_tool_definition({module, name, arity, description}) do
    tool_name = "#{module}:#{name}/#{arity}"

    %{
      "name" => tool_name,
      "description" => description || "#{module}.#{name} with arity #{arity}",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "arguments" => %{
            "type" => "array",
            "description" => "Function arguments (#{arity} expected)",
            "items" => %{"type" => "string"}
          }
        },
        "required" => ["arguments"]
      }
    }
  end
end
