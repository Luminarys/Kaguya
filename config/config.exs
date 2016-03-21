use Mix.Config

config :kaguya,
  server: "my.irc.server",
  port: 6666,
  bot_name: "kaguya",
  channels: ["#kaguya"]

# This is a bit of a hack...
if File.exists?("config/secret.exs"), do: import_config "secret.exs"
