defmodule Kaguya.Util do
  alias Kaguya.Core.Message, as: Message

  @doc """
  Sends the USER command to the IRC server, with the given name,
  and an optional realname param.
  """
  def sendUser(user, realname \\ "") do
    if realname == "" do
      realname = user
    end
    m = %Message{command: "USER", args: [user, 8, "*"], trailing: realname}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sends the NICK command to the IRC server, with the given nick.
  """
  def sendNick(nick) do
    m = %Message{command: "NICK", args: [nick]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sends a WHOIS query to a server for a nick and returns a Kaguya.Core.User struct if
  it was succesful. Otherwise nil is returned.
  """
  def getWhois(nick) do
    match_fun =
      fn msg ->
        case msg.command do
          "311" ->
            {true, %Kaguya.Core.User{
              nick: Enum.at(msg.args, 1),
              name: Enum.at(msg.args, 2),
              rdns: Enum.at(msg.args, 3),
            }}
          "401" -> {true, nil}
          _ -> false
        end
      end

    Task.async(fn ->
      :timer.sleep(100)
      m = %Message{command: "WHOIS", args: [nick]}
      :ok = GenServer.call(Kaguya.Core, {:send, m})
    end)

    try do
      GenServer.call(Kaguya.Module.Core, {:add_callback, match_fun}, 3000)
    catch
      :exit, _ -> GenServer.cast(Kaguya.Module.Core, {:remove_callback, self})
      nil
    end
  end

  @doc """
  Sends the PASS command to the IRC server with
  the given password
  """
  def sendPass(password) do
    m = %Message{command: "PASS", args: [password]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sends a PRIVMSG to a recipient on the IRC server.
  """
  def sendPM(message, recipient) do
    m = %Message{command: "PRIVMSG", args: [recipient], trailing: message}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sends a NOTICE to a recipient on the IRC server.
  """
  def sendNotice(message, recipient) do
    m = %Kaguya.Core.Message{command: "NOTICE", args: [recipient], trailing: message} 
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end
  
  @doc """
  Kicks `user` from `chan`.
  """
  def kick(chan, user) do
    m = %Kaguya.Core.Message{command: "KICK", args: [chan, user]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Kicks `user` from `chan` with the reason `reason`.
  """
  def kick(reason, chan, user) do
    m = %Kaguya.Core.Message{command: "KICK", args: [chan, user, reason]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sets MODE +b on `mask` in `chan` where `mask` can be *!*@vhost.com
  This bans a user from `chan`.
  """
  def ban(chan, mask) do
    m = %Kaguya.Core.Message{command: "MODE", args: [chan, "+b", mask]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sets MODE -b on `mask` in `chan` where `mask` can be *!*@vhost.com
  This unbans a user from `chan`.
  """
  def unban(chan, mask) do
    m = %Kaguya.Core.Message{command: "MODE", args: [chan, "-b", mask]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sets MODE `mode` on `trailing` in `chan`.
  Example:
    `chan` is "#sekrit",
    `mode` is "+b"
    and `trailing` is "baduser"

    This will set +b on baduser!*@*
  """
  def setMode(chan, mode, trailing) do
    m = %Kaguya.Core.Message{command: "MODE", args: [chan, mode, trailing]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sets MODE `mode` on `chan`.
  Example:
    `chan` is "#sekrit"
    `mode` is "+s"

    This will make the #sekrit channel secret.
  """
  def setMode(chan, mode) do
    m = %Kaguya.Core.Message{command: "MODE", args: [chan, mode]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sends the IRC server the JOIN command.
  """
  def joinChan(channel) do
    m = %Message{command: "JOIN", args: [channel]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Sends the IRC server the PART command.
  """
  def partChan(channel) do
    m = %Message{command: "PART", args: [channel]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  @doc """
  Looks up a channel's pid and returns it if it exists,
  nil otherwise.
  """
  def getChanPid(channel) do
    case :ets.lookup(:channels, channel) do
      [{^channel, pid}] -> pid
      [] -> nil
    end
  end

  @doc """
  Loads a module.
  """
  def loadModule(module) do
    case :ets.lookup(:modules, module) do
      [{^module, pid}] ->
        GenServer.cast(pid, :load)
        :ok
      _ -> :notfound
    end
  end

  @doc """
  Unloads a module.
  """
  def unloadModule(module) do
    case :ets.lookup(:modules, module) do
      [{^module, pid}] ->
        GenServer.cast(pid, :unload)
        :ok
      _ -> :notfound
    end
  end

  @doc """
  Unloads then loads a module.
  """
  def reloadModule(module) do
    case :ets.lookup(:modules, module) do
      [{^module, pid}] ->
        GenServer.cast(pid, :unload)
        GenServer.cast(pid, :load)
        :ok
      _ -> :notfound
    end
  end

  def clear, do: ""
  def white, do: "00"
  def black, do: "01"
  def blue, do: "02"
  def green, do: "03"
  def lightred, do: "04"
  def red, do: "05"
  def magenta, do: "06"
  def brown, do: "07"
  def yellow, do: "08"
  def lightgreen, do: "09"
  def cyan, do: "10"
  def lightcyan, do: "11"
  def lightblue, do: "12"
  def lightmagenta, do: "13"
  def darkgray, do: "14"
  def gray, do: "15"

  def italic, do: ""
  def bold, do: ""
  def underline, do: "\x1F"
end
