defmodule Kaguya do
  @moduledoc """
  Top level module responsible for starting the bot properly.
  """
  use Application

  @doc """
  Starts the bot, checking for proper configuration first.

  Raises exception on incomplete configuration.
  """
  def start(_type, _args) do
    opts = Application.get_all_env(:kaguya)
    if Enum.all?([:bot_name, :server, :port], &(Map.has_key?(opts, &1))) do
      start_bot()
    else
      raise "You must provide configuration options for the server, port, and bot name!"
    end
  end

  defp start_bot do
    import Supervisor.Spec
    require Logger
    Logger.log :debug, "Starting bot!"

    :pg2.start()
    :pg2.create(:modules)
    :pg2.create(:channels)

    :ets.new(:channels, [:set, :named_table, :public, {:read_concurrency, true}, {:write_concurrency, true}])
    :ets.new(:modules, [:set, :named_table, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    children = [
      supervisor(Kaguya.ChannelSupervisor, [[name: Kaguya.ChannelSupervisor]]),
      supervisor(Kaguya.ModuleSupervisor, [[name: Kaguya.ModuleSupervisor]]),
      worker(Kaguya.Core, [[name: Kaguya.Core]]),
    ]

    Logger.log :debug, "Starting supervisors!"
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
