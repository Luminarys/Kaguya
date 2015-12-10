defmodule Kaguya.Util do
  alias Kaguya.Core.Message, as: Message

  def sendUser(user, realname \\ "") do
    if realname == "" do
      realname = user
    end
    m = %Message{command: "USER", args: [user, 8, "*"], trailing: realname}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  def sendNick(nick) do
    m = %Message{command: "NICK", args: [nick]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  def sendPM(message, recipient) do
    m = %Message{command: "PRIVMSG", args: [recipient], trailing: message}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  def joinChan(channel) do
    m = %Message{command: "JOIN", args: [channel]}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end
end
