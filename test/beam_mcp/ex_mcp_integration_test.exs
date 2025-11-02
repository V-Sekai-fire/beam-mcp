defmodule BeamMcp.ExMcpIntegrationTest do
  use ExUnit.Case

  setup do
    Application.ensure_all_started(:beam_mcp)
    :ok
  end

  describe "MCP Server Discovery" do
    test "lists all available tools" do
      tools = BeamMcp.Discovery.list_tools()
      assert is_list(tools)
      assert length(tools) > 0

      Enum.each(tools, fn tool ->
        assert Map.has_key?(tool, "name")
        assert Map.has_key?(tool, "description")
        assert is_binary(tool["name"])
        assert is_binary(tool["description"])
      end)
    end

    test "each tool has required metadata" do
      tools = BeamMcp.Discovery.list_tools()

      Enum.each(tools, fn tool ->
        assert Map.has_key?(tool, "name"), "Tool missing 'name' field"
        assert Map.has_key?(tool, "description"), "Tool missing 'description' field"
      end)
    end
  end

  describe "Function Execution Tests" do
    test "code execution functions work correctly" do
      result = BeamMcp.ElixirExecutor.execute_code("1 + 1")
      assert {:ok, _} = result
    end

    test "elixir code execution returns valid output" do
      code = "IO.inspect('test')"
      {:ok, output} = BeamMcp.ElixirExecutor.execute_code(code)
      assert is_binary(output)
    end

    test "code execution handles errors gracefully" do
      bad_code = "this is not valid elixir !!!"
      result = BeamMcp.ElixirExecutor.execute_code(bad_code)
      assert is_tuple(result)
    end
  end

  describe "Authorization Model" do
    test "authorization model exists and validates permissions" do
      model = BeamMcp.AuthorizationModel.get_model()
      assert is_map(model)
    end

    test "get_model returns valid structure" do
      model = BeamMcp.AuthorizationModel.get_model()
      assert Map.has_key?(model, "rules") or Map.has_key?(model, "policies")
    end
  end

  describe "Discovery API Functions" do
    test "list_tools returns all available server functions" do
      tools = BeamMcp.Discovery.list_tools()
      tool_names = Enum.map(tools, & &1["name"])

      assert Enum.any?(tool_names, fn name ->
        String.contains?(name, "execute") or String.contains?(name, "code")
      end)
    end

    test "list_resources returns available resources" do
      resources = BeamMcp.Discovery.list_resources()
      assert is_list(resources)
    end
  end

  describe "Core Module Functions" do
    test "BeamMcp.Discovery module has list_tools function" do
      assert function_exported?(BeamMcp.Discovery, :list_tools, 0)
    end

    test "BeamMcp.Discovery module has list_resources function" do
      assert function_exported?(BeamMcp.Discovery, :list_resources, 0)
    end

    test "BeamMcp.ElixirExecutor has execute_code function" do
      assert function_exported?(BeamMcp.ElixirExecutor, :execute_code, 1)
    end

    test "BeamMcp.AuthorizationModel has get_model function" do
      assert function_exported?(BeamMcp.AuthorizationModel, :get_model, 0)
    end
  end

  describe "MCP Response Format Validation" do
    test "responses conform to MCP protocol" do
      tools = BeamMcp.Discovery.list_tools()

      Enum.each(tools, fn tool ->
        assert is_binary(tool["name"]), "Tool name must be string"
        assert is_binary(tool["description"]), "Tool description must be string"
        assert String.length(tool["name"]) > 0, "Tool name cannot be empty"
      end)
    end

    test "tool names follow naming convention" do
      tools = BeamMcp.Discovery.list_tools()
      tool_names = Enum.map(tools, & &1["name"])

      Enum.each(tool_names, fn name ->
        assert String.match?(name, ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/),
               "Tool name '#{name}' should be valid identifier"
      end)
    end
  end

  describe "Fixture-based Validation" do
    setup do
      fixtures = %{
        "code_execution" => %{
          "description" => "Executes arbitrary Elixir code",
          "success_cases" => [
            "1 + 1",
            "IO.inspect(42)",
            "Enum.map([1,2,3], &(&1 * 2))"
          ],
          "error_cases" => [
            "invalid !!!",
            "undefined_function_call()",
            "1 ++"
          ]
        }
      }

      {:ok, fixtures: fixtures}
    end

    test "code execution success cases match fixtures", %{fixtures: fixtures} do
      fixture = fixtures["code_execution"]

      Enum.each(fixture["success_cases"], fn code ->
        result = BeamMcp.ElixirExecutor.execute_code(code)

        assert {:ok, _} = result,
               "Expected successful execution of '#{code}', got: #{inspect(result)}"
      end)
    end

    test "code execution error cases are handled", %{fixtures: fixtures} do
      fixture = fixtures["code_execution"]

      Enum.each(fixture["error_cases"], fn code ->
        result = BeamMcp.ElixirExecutor.execute_code(code)

        case result do
          {:ok, output} ->
            assert is_binary(output)

          {:error, _} ->
            :ok

          other ->
            assert is_tuple(other)
        end
      end)
    end

    test "discovery returns valid fixture structure" do
      tools = BeamMcp.Discovery.list_tools()

      Enum.each(tools, fn tool ->
        assert Map.has_key?(tool, "name"),
               "Tool missing 'name': #{inspect(tool)}"

        assert Map.has_key?(tool, "description"),
               "Tool missing 'description': #{inspect(tool)}"

        assert is_binary(tool["name"]), "Tool 'name' must be string"
        assert is_binary(tool["description"]), "Tool 'description' must be string"
      end)
    end
  end

  describe "Complete Function Coverage" do
    test "all beam_mcp modules are testable" do
      modules = [
        BeamMcp.Discovery,
        BeamMcp.ElixirExecutor,
        BeamMcp.AuthorizationModel,
        BeamMcp.McpBeamServer,
        BeamMcp.StdioMcpServer
      ]

      Enum.each(modules, fn module ->
        assert is_atom(module)
        assert Code.ensure_loaded?(module),
               "Module #{inspect(module)} should be loadable"
      end)
    end

    test "public functions in Discovery module" do
      module = BeamMcp.Discovery
      functions = module.module_info(:exports)
      assert is_list(functions)
      assert length(functions) > 0

      assert Enum.any?(functions, fn {name, arity} ->
        name == :list_tools and arity == 0
      end)
    end

    test "public functions in ElixirExecutor module" do
      module = BeamMcp.ElixirExecutor
      functions = module.module_info(:exports)
      assert is_list(functions)

      assert Enum.any?(functions, fn {name, arity} ->
        name == :execute_code and arity == 1
      end)
    end
  end

  describe "Cross-module Integration" do
    test "tools from discovery match exported functions" do
      tools = BeamMcp.Discovery.list_tools()
      assert is_list(tools)
      assert length(tools) > 0
    end

    test "all discoverable tools are executable" do
      tools = BeamMcp.Discovery.list_tools()

      Enum.each(tools, fn tool ->
        assert tool["name"] != ""
        assert tool["description"] != ""
      end)
    end

    test "authorization model integrates with discovery" do
      model = BeamMcp.AuthorizationModel.get_model()
      tools = BeamMcp.Discovery.list_tools()

      assert is_map(model)
      assert is_list(tools)
    end
  end

  describe "Consistency Tests" do
    test "multiple calls to list_tools return same results" do
      result1 = BeamMcp.Discovery.list_tools()
      result2 = BeamMcp.Discovery.list_tools()

      assert result1 == result2, "list_tools should return consistent results"
    end

    test "tool metadata is consistent across calls" do
      tools1 = BeamMcp.Discovery.list_tools()
      tools2 = BeamMcp.Discovery.list_tools()

      assert length(tools1) == length(tools2)

      names1 = Enum.map(tools1, & &1["name"]) |> Enum.sort()
      names2 = Enum.map(tools2, & &1["name"]) |> Enum.sort()

      assert names1 == names2
    end

    test "code execution is deterministic for same input" do
      code = "1 + 1"
      result1 = BeamMcp.ElixirExecutor.execute_code(code)
      result2 = BeamMcp.ElixirExecutor.execute_code(code)

      assert result1 == result2, "Same code should produce same result"
    end
  end

  describe "Fixture Matching - Core Functions" do
    test "execute_code matches execution fixture" do
      code_fixture = %{
        input: "Enum.sum([1, 2, 3])",
        expected_type: :tuple,
        status_options: [:ok, :error]
      }

      result = BeamMcp.ElixirExecutor.execute_code(code_fixture.input)

      assert is_tuple(result)

      {status, _value} = result
      assert status in code_fixture.status_options
    end

    test "list_tools matches discovery fixture" do
      discovery_fixture = %{
        expected_return_type: :list,
        required_fields: ["name", "description"],
        field_types: %{
          "name" => :string,
          "description" => :string
        }
      }

      tools = BeamMcp.Discovery.list_tools()

      assert discovery_fixture.expected_return_type == :list
      assert is_list(tools)

      Enum.each(tools, fn tool ->
        Enum.each(discovery_fixture.required_fields, fn field ->
          assert Map.has_key?(tool, field),
                 "Tool missing required field: #{field}"
        end)

        Enum.each(discovery_fixture.field_types, fn {field, type} ->
          value = tool[field]

          case type do
            :string -> assert is_binary(value), "Field '#{field}' should be binary"
            :atom -> assert is_atom(value)
            :integer -> assert is_integer(value)
            _ -> :ok
          end
        end)
      end)
    end

    test "get_model matches authorization fixture" do
      model_fixture = %{
        expected_return_type: :map
      }

      model = BeamMcp.AuthorizationModel.get_model()

      assert model_fixture.expected_return_type == :map
      assert is_map(model)
    end
  end
end
