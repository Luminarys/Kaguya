defmodule Kaguya.Channel do
  use GenServer

  alias Kaguya.ChannelSupervisor, as: ChanSup
  alias Kaguya.Util, as: Util

  def start_link(name, opts) do
    GenServer.start_link(__MODULE__, {name}, opts)
  end

  def init({name}) do
    require Logger
    Logger.log :debug, "Started channel #{name}!"
    :pg2.join(:channels, self)
    :ets.insert(:channels, {name, self})
    users = :ets.new(:users, [:set, :protected])
    {:ok, {name, users}}
  end

  def handle_call({:send, message}, _from, {name, _users} = state) do
    Kaguya.Util.sendPM(name, message)
    {:reply, :ok, state}
  end

  defmodule Kaguya.Channel.User do
    @moduledoc """
    Representation of a user in a channel.
    """
    defstruct nick: "", mode: :normal
  end

  def handle_call({:rename_user, {old_nick, new_nick}}, _from, {_name, users} = state) do
    [{^old_nick, user}] = :ets.lookup(users, old_nick)
    new_user = %{user | nick: new_nick}
    :ets.delete(users, old_nick)
    :ets.insert(users, {new_nick, new_user})
    {:reply, :ok, state}
  end

  def handle_call({:set_user, nick_mode}, _from, {_name, users} = state) do
    mode_sym = String.first(nick_mode)
    mode =
    case mode_sym do
      "~" -> :owner
      "&" -> :admin
      "@" -> :op
      "+" -> :voice
      _ -> :normal
    end

    nick =
    if mode == :normal do
      nick_mode
    else
      String.slice(nick_mode, 1, 1000)
    end

    user = %Kaguya.Channel.User{nick: nick, mode: mode}
    :ets.insert(users, {nick, user})
    {:reply, :ok, state}
  end

  def handle_call({:get_user, nick}, _from, {_name, users} = state) do
    case :ets.lookup(users, nick) do
      [{^nick, user}] -> {:reply, user, state}
      [] -> {:reply, nil, state}
    end
  end

  def handle_call({:del_user, nick}, _from, {_name, users} = state) do
    :ets.delete(users, nick)
    {:reply, :ok, state}
  end

  def join(channel) do
    {:ok, _pid} = Supervisor.start_child(ChanSup, [channel, []])
    Util.joinChan(channel)
  end

  def set_user(chan, nick) do
    [{^chan, pid}] = :ets.lookup(:channels, chan)
    :ok = GenServer.call(pid, {:set_user, nick})
  end
end
