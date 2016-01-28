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
    match "!ping", :pingHandler
    match "!say ~message", :sayHandler
  end

  def pingHandler(message), do: reply "pong!"
  def sayHandler(message, %{message: response}), do: reply response
end
```

This module defines two commands to be handled. `!ping`, to which the bot
will respond `pong!`, and `!say [some message]` which will have
the bot echo the message the user gave. The `~` indicates a
trailing match in which all characters following `!say ` will be matched
against.

Just by having your module use Kaguya.Module, it will automatically be added
to the module list which receives all IRC messages and is launched at start time.

You can find a more full featured example in `example/basic.ex`.
