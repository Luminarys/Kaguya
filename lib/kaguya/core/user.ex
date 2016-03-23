defmodule Kaguya.Core.User do
  @moduledoc """
  Struct representation of an IRC user. It has three fields, nick, name, and rdns.
  rdns is just the final part of the prefix, it's sometimes known as host or vhost.
  """
  defstruct nick: "", name: "", rdns: ""
end
