defmodule Kaguya.Module.Builtin do
  use Kaguya.Module, "builtin"

  handle "PING" do
    match_all :pingHandler
  end

  handle "433" do
    match_all :retryNick
  end

  handle "353" do
    match_all :setChanNicks
  end

  handle "001" do
    match_all :joinInitChans
  end

  handle "MODE" do
    match_all :changeUserMode
  end

  handle "NICK" do
    match_all :changeUserNick
  end

  def pingHandler(message) do
    m = %{message | command: "PONG"}
    :ok = GenServer.call(Kaguya.Core, {:send, m})
  end

  def noticeHandler(_message, %{"param" => param}) do
    IO.puts "MATCHED: #{param}"
  end

  def retryNick(%{args: [_unused, nick]}) do
    Kaguya.Util.sendNick(nick <> "_")
  end

  def joinInitChans(_message) do
    chans = Application.get_env(:kaguya, :channels)
    for chan <- chans, do: Kaguya.Channel.join(chan)
  end

  def setChanNicks(%{args: [_nick, _sign, chan], trailing: nick_string}) do
    nicks = String.split(nick_string)
    for nick <- nicks, do: Kaguya.Channel.set_user(chan, nick)
  end

  def changeUserMode(%{args: [chan, mode, nick]}) do
    case mode do
      "+v" -> Kaguya.Channel.set_user(chan, "+#{nick}")
      "+h" -> Kaguya.Channel.set_user(chan, "%#{nick}")
      "+o" -> Kaguya.Channel.set_user(chan, "@#{nick}")
    end
  end

  def changeUserNick(%{trailing: new_nick, user: %{nick: old_nick}}) do
    for member <- :pg2.get_members(:channels), do: GenServer.call(member, {:rename_user, {old_nick, new_nick}})
  end
end
