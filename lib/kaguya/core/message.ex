defmodule Kaguya.Core.Message do
  @moduledoc """
  Representation of an IRC message in struct form.
  The trailing argument is the final argument, separated
  for convenience.

  The struct has four fields, command, args, trailing, and user.
  The command is the IRC command, such as PRIVMSG. The args are a list of
  IRC params, excluding the final param(which is ":" prefixed). This final param
  is the trailing struct field. The user field is a struct `Kaguya.Core.User`, and
  is converted from the prefix of the IRC message.
  """
  defstruct command: "", args: [], trailing: "", user: nil
end
