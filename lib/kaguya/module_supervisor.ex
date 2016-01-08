defmodule Kaguya.ModuleSupervisor do
  use Supervisor
  require Logger

  @moduledoc """
  Module supervisor. It runs all modules specified in the :modules
  configuration option for :kaguya.
  """

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    # modules = [Kaguya.Module.Builtin|Application.get_env(:kaguya, :modules)]
    modules = Application.get_env(:kaguya, :modules)
    children = for module <- modules do
      worker(module, [])
    end
    Logger.log :debug, "Starting modules!"
    supervise(children, strategy: :one_for_one)
  end
end
