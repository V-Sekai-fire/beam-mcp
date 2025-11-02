defmodule BeamMcp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {BeamMcp.CnodeBridge.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: BeamMcp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
