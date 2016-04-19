use Mix.Config

config :kaguya,
  server: "my.irc.server",
  # Should be either :inet or :inet6 if ipv6
  server_ip_type: :inet,
  port: 6666,
  bot_name: "kaguya",
  channels: ["#kaguya"],
  help_cmd: ".help",
  use_ssl: false

# This is a bit of a hack...
if File.exists?("config/secret.exs"), do: import_config "secret.exs"
