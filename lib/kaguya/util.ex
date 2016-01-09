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
  Sends the IRC server the JOIN command.
  """
  def joinChan(channel) do
    m = %Message{command: "JOIN", args: [channel]}
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
