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

This module defines four commands to be handled. `!ping` and `!p` are
aliased to the same handler, which has the bot respond `pong!`.
The bot will also match the phrase "hi", and respond by saying hi back to that person with
their nick. Last, `!say [some message]` will have
the bot echo the message the user gave. The `~` indicates a
trailing match in which all characters following `!say ` will be matched
against. You may notice that there are two different maps in the handlers for hi and say.
This is because the defh macro automatically infers whether or not the maps provided to it as arguments
refer to the match arguments, or the message parameters. It should also be noted that within the function,
two variables are unhygienically exposed via the macro, `message` and `args`. If for some reason you want to access
the message struct and the argument map manually, these should be used.

Just by having your module use Kaguya.Module, it will automatically be added
to the module list which receives all IRC messages and is launched at start time.

You can find a more full featured example in `example/basic.ex`.
