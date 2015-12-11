defmodule Kaguya.Channel do
  use GenServer

  alias Kaguya.ChannelSupervisor, as: ChanSup
  alias Kaguya.Util, as: Util

  @moduledoc """
  Channel GenServer, with a few utility functions for working with
  channels. As a GenServer, it can be called in the following ways:
  * {:send, message}, where message is the message to be sent to the channel
  * {:set_user, nick_string}, where the nick string is a nick with the mode prefix(+, @, etc.)
  * {:get_user, nick}, where nick is the nick of the user to be returned.
  The Kaguya.Channel.User struct is returned
  * {:del_user, nick}, where nick is the nick of the user to be deleted
  """

  @max_buffer 10000

  defmodule User do
    @moduledoc """
    Representation of a user in a channel.
    """
    defstruct nick: "", mode: :normal
  end

  @doc """
  Starts a channel worker with the given name
  and options
  """
  def start_link(name, opts \\ []) do
    GenServer.start_link(__MODULE__, {name}, opts)
  end

  def init({name}) do
    require Logger
    Logger.log :debug, "Started channel #{name}!"
    :pg2.join(:channels, self)
    :ets.insert(:channels, {name, self})
    users = :ets.new(:users, [:set, :protected])
    {:ok, {name, users, []}}
  end

  def handle_call({:send, message}, _from, {name, _users, _buffer} = state) do
    Kaguya.Util.sendPM(name, message)
    {:reply, :ok, state}
  end

  def handle_call({:rename_user, {old_nick, new_nick}}, _from, {_name, users, _buffer} = state) do
    case :ets.lookup(users, old_nick) do
      [{^old_nick, user}] ->
        new_user = %{user | nick: new_nick}
        :ets.delete(users, old_nick)
        :ets.insert(users, {new_nick, new_user})
      [] -> :ok
    end
    {:reply, :ok, state}
  end

  def handle_call({:set_user, nick_mode}, _from, {_name, users, _buffer} = state) do
    mode_sym = String.first(nick_mode)
    mode =
    case mode_sym do
      "~" -> :op
      "&" -> :op
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

  def handle_call({:get_user, nick}, _from, {_name, users, _buffer} = state) do
    case :ets.lookup(users, nick) do
      [{^nick, user}] -> {:reply, user, state}
      [] -> {:reply, nil, state}
    end
  end

  def handle_call({:del_user, nick}, _from, {_name, users, _buffer} = state) do
    :ets.delete(users, nick)
    {:reply, :ok, state}
  end

  def handle_call({:log_message, msg}, _from, {name, users, buffer}) do
    new_buffer =
    if Enum.count(buffer) > @max_buffer do
      [msg|buffer] |> Enum.drop(-1)
    else
      [msg|buffer]
    end
    {:reply, :ok, {name, users, new_buffer}}
  end

  def handle_call({:get_buffer, fun}, _from, {_name, _users, buffer} = state) do
    {:reply, fun.(buffer), state}
  end

  @doc """
  Convnenience function to join the specified channel.
  """
  def join(channel) do
    {:ok, _pid} = Supervisor.start_child(ChanSup, [channel, []])
    Util.joinChan(channel)
  end

  @doc """
  Convenience function to send a nickstring to a channel.
  """
  def set_user(chan, nick) do
    [{^chan, pid}] = :ets.lookup(:channels, chan)
    :ok = GenServer.call(pid, {:set_user, nick})
  end

  @doc """
  Convenience function to remove a nick from a channel.
  """
  def del_user(chan, nick) do
    [{^chan, pid}] = :ets.lookup(:channels, chan)
    :ok = GenServer.call(pid, {:del_user, nick})
  end

  @doc """
  Convenience function to perform a function on a channel's buffer
  and get the result.
  """
  def get_buffer(chan, fun) do
    [{^chan, pid}] = :ets.lookup(:channels, chan)
    GenServer.call(pid, {:get_buffer, fun})
  end
end
