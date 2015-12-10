# Kaguya

**A small, but powerful IRC bot**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add kaguya to your list of dependencies in `mix.exs`:

        def deps do
          [{:kaguya, "~> 0.0.1"}]
        end

  2. Ensure kaguya is started before your application:

        def application do
          [applications: [:kaguya]]
        end

  3. Configure kaguya in config.exs:

        config :kaguya,
          server: "my.irc.server",
          port: 6666,
          bot_name: "kaguya",
          modules: [],
          channels: ["#kaguya"]

## Usage
By default Kaguya won't do much. This is an example of a module which will
perform a few simple commands:
```
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
Once you've written a module you need to specify that it be loaded.
You can do this my modifying the config parameter `modules` to include
the name of the module you wrote. In the config would look like:
```
  config :kaguya,
    ...
    modules: [Kaguya.Module.Simple, ...],
    ...
```
