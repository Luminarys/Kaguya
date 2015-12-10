defmodule Kaguya.ModuleSupervisor do
  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    modules = [Kaguya.Module.Builtin|Application.get_env(:kaguya, :modules)]
    children = for module <- modules, do: worker(module, [])
    Logger.log :debug, "Starting modules!"
    supervise(children, strategy: :one_for_one)
  end
end
