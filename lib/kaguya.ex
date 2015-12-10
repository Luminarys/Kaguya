defmodule Kaguya do
  @moduledoc """
  Begins the execution of the bot.
  """
  use Application
  use Supervisor

  def start(_type, _args) do
    require Logger
    Logger.log :debug, "Starting bot!"

    :pg2.start()
    :pg2.create(:modules)
    :pg2.create(:channels)

    :ets.new(:channels, [:set, :named_table, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    children = [
      supervisor(Kaguya.ModuleSupervisor, [[name: Kaguya.ModuleSupervisor]]),
      supervisor(Kaguya.ChannelSupervisor, [[name: Kaguya.ChannelSupervisor]]),
      worker(Kaguya.Core, [[name: Kaguya.Core]])
    ]

    Logger.log :debug, "Starting supervisors!"
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
