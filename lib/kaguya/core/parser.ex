defmodule Kaguya.Core.Parser do
  @moduledoc """
  Module which handles message parsing from struct to raw
  form and vice versa.
  """
  alias Kaguya.Core.Message, as: Message
  alias Kaguya.Core.User, as: User
  @doc """
  Converts a raw string into an IRC message.
  """
  def parse_raw_to_message(raw) do
    raw
    |> parse_user
    |> get_args_and_trailing
    |> make_message
  end

  defp parse_user(raw) do
    if String.first(raw) == ":" do
      [user_info, message] = String.split(raw, " ", parts: 2)
      case String.split(user_info, "!") do
        [server] -> 
          s = %User{nick: String.lstrip(server, ?:)}
          {s, message}
        [nick, info] ->
          nick = String.lstrip(nick, ?:)
          [name, rdns] = String.split(info, "@")
          {%User{nick: nick, name: name, rdns: rdns}, message}
      end
    else
      {%User{}, raw}
    end
  end

  defp get_args_and_trailing({user, message}) do
    case String.contains?(message, ":") do
      true ->
        [args, trailing] = message |> String.rstrip |> String.split(" :", parts: 2)
        [command|arg_list] = String.split(args)
        {command, arg_list, trailing, user}
      false ->
        [command|arg_list] = message |> String.rstrip |> String.split
        {command, arg_list, "", user}
    end
  end

  defp make_message({command, arg_list, trailing, user}) do
    %Message{user: user, command: command, args: arg_list, trailing: trailing}
  end

  @doc """
  Converts a message struct into a raw string in BNF format.
  """
  def parse_message_to_raw(message) do
    message
    |> add_prefix
    |> add_args
    |> add_trailing
  end

  defp add_prefix(%Message{command: command} = message), do: {"#{command} ", message}

  defp add_args({raw, message}) do
    case message.args do
      [] -> {raw, message}
      args -> {"#{raw}#{Enum.join(args, " ")} ", message}
    end
  end

  defp add_trailing({raw, message}) do
    case message.trailing do
      "" -> "#{raw}\r\n"
      trailing -> "#{raw}:#{trailing}\r\n"
    end
  end
end
