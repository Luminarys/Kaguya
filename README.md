# Kaguya

**A small but powerful IRC bot**

## Installation

1. Add kaguya to your list of dependencies in `mix.exs`:
```elixir
def deps do
  [{:kaguya, "~> x.y.z"}]
end
```

2. Run `mix deps.get`

3. Ensure kaguya is started before your application:
```elixir
def application do
  [applications: [:kaguya]]
end
```

4. Configure kaguya in config.exs:
```elixir
config :kaguya,
  server: "my.irc.server",
  port: 6666,
  bot_name: "kaguya",
  channels: ["#kaguya"]
```

## Usage
By default Kaguya won't do much. This is an example of a module which will
perform a few simple commands:
```elixir
defmodule Kaguya.Module.Simple do
  use Kaguya.Module, "simple"

  handle "PRIVMSG" do
    match ["!ping", "!p"], :pingHandler
    match "hi", :hiHandler
    match "!say ~message", :sayHandler
  end

  defh pingHandler, do: reply "pong!"
  defh hiHandler(%{user: %{nick: nick}}), do: reply "hi #{nick}!"
  defh sayHandler(%{"message" => response}), do: reply response
end
```

This module defines four commands to be handled: 
* `!ping` and `!p` are aliased to the same handler, which has the bot respond `pong!`.
* `hi` will cause the bot to reply saying "hi" with the persons' nick
* `!say [some message]` will have the bot echo the message the user gave.

The handler macro can accept up to two different parameters, a map which destructures a message struct, and a map which destructures a match from a command.

You can find a more full featured example in `example/basic.ex`.
