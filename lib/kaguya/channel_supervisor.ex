defmodule Kaguya.ChannelSupervisor do
  use Supervisor
  import Supervisor.Spec

  @moduledoc """
  The channel supervisor. It uses a simple_one_for_one format,
  with transient restarts.
  """

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      worker(Kaguya.Channel, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
