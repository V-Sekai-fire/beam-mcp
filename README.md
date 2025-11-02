# BeamMCP - MCP Bridge for Erlang Cnodes

An Elixir project that bridges the Model Context Protocol (MCP) with Erlang distributed cnodes, enabling MCP clients to interact with services running on remote Erlang nodes.

## Features

- **MCP-Cnode Integration**: Bridge MCP protocol with distributed Erlang cnodes
- **Tool Calling**: Forward tool calls from MCP clients to remote cnodes
- **Resource Management**: Read resources from remote cnode services
- **Async RPC Communication**: Use Erlang RPC for inter-node communication
- **Comprehensive Testing**: Full test suite with Mox mocking framework
- **Ex-MCP Integration**: Built on the latest ex_mcp master branch

## Project Structure

```
beam-mcp/
├── lib/
│   └── beam_mcp/
│       ├── application.ex              # OTP Application entrypoint
│       ├── cnode_bridge.ex             # Main bridge interface
│       ├── cnode_handler.ex            # Behaviour for cnode handlers
│       └── cnode_bridge/
│           ├── server.ex               # GenServer managing bridge
│           └── supervisor.ex           # Supervision tree
├── test/
│   ├── test_helper.exs                 # Test setup with Mox
│   └── beam_mcp/
│       └── cnode_bridge_test.exs       # Bridge tests
├── mix.exs                             # Project configuration
└── README.md                           # This file
```

## Installation

### Prerequisites

- Elixir 1.14 or higher
- Erlang/OTP 25 or higher

### Setup

1. Clone the repository:
```bash
git clone https://github.com/V-Sekai-fire/beam-mcp.git
cd beam-mcp
```

2. Install dependencies:
```bash
mix deps.get
```

3. Compile:
```bash
mix compile
```

4. Run tests:
```bash
mix test
```

## Usage

### Starting a Bridge to a Cnode

```elixir
# Start the bridge with connection details
{:ok, bridge_info} = BeamMcp.CnodeBridge.start_bridge(
  cnode_name: "my_cnode",
  cookie: "secret_erlang_cookie",
  cnode_host: "localhost",
  mcp_name: "my_bridge",
  tools: [
    %{name: "tool1", description: "First tool"},
    %{name: "tool2", description: "Second tool"}
  ],
  resources: [
    %{uri: "file://data", description: "Data resource"}
  ]
)
```

### Calling Tools Through the Bridge

```elixir
# Call a tool on the remote cnode
{:ok, result} = BeamMcp.CnodeBridge.call_tool("my_bridge", "tool_name", %{
  arg1: "value1",
  arg2: "value2"
})
```

### Listing Available Tools

```elixir
# Get tools from the remote cnode
{:ok, tools} = BeamMcp.CnodeBridge.list_tools("my_bridge")

Enum.each(tools, fn tool ->
  IO.puts("Tool: #{tool["name"]}")
  IO.puts("Description: #{tool["description"]}")
end)
```

### Reading Resources

```elixir
# Read a resource from the remote cnode
{:ok, content} = BeamMcp.CnodeBridge.read_resource("my_bridge", "file://data/resource.txt")

IO.puts(content)
```

### Stopping the Bridge

```elixir
# Stop the bridge
BeamMcp.CnodeBridge.stop_bridge(bridge_info)
```

## Implementing a Cnode Handler

On your remote cnode, implement the `BeamMcp.CnodeHandler` behaviour:

```elixir
defmodule MyApp.CnodeHandler do
  @behaviour BeamMcp.CnodeHandler

  @impl true
  def handle_mcp_request(:list_tools) do
    [
      %{
        "name" => "my_tool",
        "description" => "A sample tool",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{
            "param" => %{"type" => "string"}
          }
        }
      }
    ]
  end

  @impl true
  def handle_mcp_request({:call_tool, "my_tool", %{"param" => value}}) do
    %{
      "content" => [
        %{
          "type" => "text",
          "text" => "Processed: #{value}"
        }
      ]
    }
  end

  @impl true
  def handle_mcp_request({:read_resource, uri}) do
    case uri do
      "file://data" -> %{"content" => "Resource content"}
      _ -> {:error, "Resource not found"}
    end
  end
end
```

## Testing

The project includes comprehensive tests using the Mox mocking framework:

```bash
# Run all tests
mix test

# Run tests with verbose output
mix test -v

# Run specific test file
mix test test/beam_mcp/cnode_bridge_test.exs
```

### Test Structure

Tests are organized in `test/beam_mcp/cnode_bridge_test.exs` and cover:

- Bridge initialization with required/optional parameters
- Tool calling functionality
- Tool listing
- Resource reading
- Error handling for unavailable cnodes

## Dependencies

- **ex_mcp** (~> 0.6.0): Model Context Protocol implementation
- **mox** (~> 1.2): Mocking library for testing

See `mix.exs` for the complete dependency list.

## Architecture

### Key Components

1. **BeamMcp.Application**: OTP Application supervision tree
2. **BeamMcp.CnodeBridge**: Main API for bridge operations
3. **BeamMcp.CnodeBridge.Server**: GenServer managing individual bridge instances
4. **BeamMcp.CnodeBridge.Supervisor**: Supervision tree for bridge servers
5. **BeamMcp.CnodeHandler**: Behaviour module for cnode request handlers

### Communication Flow

```
MCP Client
    ↓
ExMCP.Client/Server
    ↓
BeamMcp.CnodeBridge (API)
    ↓
BeamMcp.CnodeBridge.Server (GenServer)
    ↓
:rpc.call() (Erlang RPC)
    ↓
Remote Cnode
    ↓
CnodeHandler (user-implemented)
```

## Configuration

No additional configuration required beyond standard Mix project setup.

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## References

- [Model Context Protocol](https://modelcontextprotocol.io/)
- [ExMCP Repository](https://github.com/azmaveth/ex_mcp)
- [Erlang Distribution](https://www.erlang.org/doc/reference_manual/distributed.html)
