defmodule Kaguya.Modules.Basic do
  use Kaguya.Module, "basic"

  validator :is_op do
    :check_is_op
  end

  def check_is_op(%{user: %{nick: nick}, args: [chan]}) do
    pid = Kaguya.Util.getChanPid(chan)
    user = GenServer.call(pid, {:get_user, nick})

    if user == nil do
      false
    else
      user.mode == :op
    end
  end

  handle "PRIVMSG" do
    match "!ping", :pingHandler
    match "!when :nick says :trigger say :repl", :whenHandler, async: true

    validate :is_op do
      match "!join :chan", :joinHandler, match_group: "[a-zA-Z0-9#&]+"
    end
  end

  def pingHandler(message), do: reply "pong!"

  def whenHandler(message, %{"nick" => nick, "trigger" => t, "repl" => r}) do
    reply "Alright."
    {msg, _resp} = await_resp "#{t}", nick: nick
    if msg != nil do
      reply "#{r}"
    end
  end

  def joinhandler(message, %{"chan" => chan}) do
    Kaguya.Channel.join(chan)
  end
end
