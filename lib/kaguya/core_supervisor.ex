defmodule Kaguya.CoreSupervisor do
  use Supervisor
  require Logger

  @moduledoc """
  The supervisor of the Core of Kaguya. It mainly exists to be proc'd by Core
  on :tcp_closed so that the Core can restart itself.
  """

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      worker(Kaguya.Core, [])
    ]
    Logger.log :debug, "Starting Core!"
    supervise(children, strategy: :one_for_one)
  end
end

defmodule Kaguya.Module.Builtin2 do
  use Kaguya.Module, "builtin2"

  handle "PRIVMSG" do
    IO.puts "PM"
  end
end
