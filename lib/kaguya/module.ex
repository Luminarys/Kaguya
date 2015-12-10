defmodule Kaguya.Module do
  use Behaviour

  @moduledoc """
  When  this module is used, it will create wrapper
  functions which allow it to be automatically registered
  as a module and include all macros. It can be included like:
  `use Kaguya.Module, "module name here"`
  """

  defmacro __using__(module_name) do
    # Module.put_attribute Kaguya, :modules, __MODULE__
    quote bind_quoted: [module_name: module_name] do
      @module_name module_name
      use GenServer
      import Kaguya.Module

      # modules = Application.get_env(:kaguya, :modules, [])
      # new_modules = [__MODULE__|modules]
      # Application.put_env(:kaguya, :modules, new_modules, persist: true)

      def start_link(opts \\ []) do
        {:ok, _pid} = GenServer.start_link(__MODULE__, :ok, [])
      end

      defoverridable start_link: 1

      def init(:ok) do
        require Logger
        Logger.log :debug, "Started module #{@module_name}!"
        :pg2.join(:modules, self)
        Process.register(self, __MODULE__)
        {:ok, []}
      end

      defoverridable init: 1

      def handle_cast({:msg, message}, state) do
        require Logger
        Logger.log :debug, "Running module #{@module_name}'s dispatcher!"
        try do
          handle_message({:msg, message}, state)
        rescue
          e in FunctionClauseError ->
            Logger.log :debug, "Message fell through for #{@module_name}!"
            {:noreply, state}
        end
      end
    end
  end

  @doc """
  Defines a group of matchers which will handle all messages of the corresponding
  IRC command.

  ## Example
  ```
  handle "PING" do
    match_all :pingHandler
    match_all :pingHandler2
  end
  ```

  In the example, all IRC messages which have the PING command
  will be matched against `:pingHandler` and `:pingHandler2`
  """
  defmacro handle(command, do: body) do
    quote do
      def handle_message({:msg, %{command: unquote(command)} = var!(message)}, state) do
        unquote(body)
        {:noreply, state}
      end
    end
  end

  @doc """
  Defines a matcher which always calls its corresponding
  function. Example: `match_all :pingHandler`
  """
  defmacro match_all(function, opts \\ []) do
    mbody =
    quote do
      unquote(function)(var!(message))
    end
    mbody |> check_async(opts)
  end

  @doc """
  Defines a matcher which will match a regex againt the trailing portion
  of an IRC message. Example: `match_re ~r"me|you", :meOrYouHandler`
  """
  defmacro match_re(re, function, opts \\ []) do
    mbody =
    quote do
      if Regex.match?(unquote(re), var!(message).trailing) do
        unquote(function)(var!(message))
      end
    end
    mbody |> check_async(opts)
  end

  @doc """
  Defines a matcher which will match a string defining
  various capture variables against the trailing portion
  of an IRC message.

  ## Example
  ```
  handle "PRIVMSG" do
    match "!rand :low :high", :genRand, match_group: "[0-9]+"
  end
  ```

  In this example, the geRand function will be called
  when a user sends a message to a channel saying something like
  `!rand 0 10`. If both parameters are strings, the genRand function
  will be passed the messages, and a map which will look like `%{low: 0, high: 10}`.

  Available match string params are `:param` and `~param`. The former
  will match a specific space separated parameter, whereas the latter matches
  an unlimited number of characters.

  Match can also be called with a few different options. Currently there are:
  * match_group - Regex which is used for matching in the match string. By default
  it is `[a-zA-Z0-9]+`
  * async - Whether or not the matcher should be run synchronously or asynchronously.
  By default it is false, but should be set to true if await_resp is to be used.
  """
  defmacro match(match_str, function, opts \\ []) do
    add_captures(match_str, function, opts)
    |> check_async(opts)
  end

  defp add_captures(match_str, function, opts) do
    if String.contains? match_str, [":", "~"] do
      match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")
      re = match_str |> extract_vars(match_group) |> Macro.escape
      quote do
        case Regex.named_captures(unquote(re), var!(message).trailing) do
          nil -> :ok
          res -> unquote(function)(var!(message), res)
        end
      end
    else
      quote do
        if var!(message).trailing == unquote(match_str) do
          unquote(function)(var!(message))
        end
      end
    end
  end

  defp extract_vars(match_str, match_group) do
    parts = String.split(match_str)
    l = for part <- parts, do: gen_part(part, match_group)
    expr = "^#{Enum.join(l, " ")}$"
    Regex.compile!(expr)
  end

  defp gen_part(part, match_group) do
    case part do
      ":" <> param -> "(?<#{param}>#{match_group})"
      "~" <> param -> "(?<#{param}>.+)"
      text -> Regex.escape(text)
    end
  end

  defp check_async(body, opts) do
    if Keyword.get(opts, :async, false) do
      quote do
        Task.start fn ->
          unquote(body)
        end
      end
    else
      body
    end
  end

  @doc """
  Creates a validation stack for use in a handler.

  ## Example:
  ```
  validator :is_me do
    :check_nick_for_me
  end

  def check_nick_for_me(%{user: %{nick: "me"}}), do: true
  def check_nick_for_me(_message), do: false
  ```

  In the example, a validator named :is_me is created.
  In the validator, any number of function can be defined
  with atoms, and they will be all called. Every validator
  function will be given a message, and should return either
  true or false.
  """
  defmacro validator(name, do: body) do
    if is_atom(body) do
      create_validator(name, [body])
    else
      {:__block__, [], funcs} = body
      create_validator(name, funcs)
    end
  end

  defp create_validator(name, funcs) do
    quote do
      def unquote(name)(message) do
        res = for func <- unquote(funcs), do: apply(__MODULE__, func, [message])
        !Enum.member?(res, false)
      end
    end
  end

  @doc """
  Creates a scope in which only messages that succesfully pass through
  the given will be used.

  ## Example:
  ```
  handle "PRIVMSG" do
    validate :is_me do
      match "Hi", :hiHandler
    end
  end
  ```

  In the example, only messages which pass through the is_me validator,
  defined prior will be matched within this scope.
  """
  defmacro validate(validator, do: body) do
    quote do
      if unquote(validator)(var!(message)) do
        unquote(body)
      end
    end
  end

  @doc """
  Sends a response to the sender of the PRIVMSG with a given message.
  Example: `reply "Hi"`
  """
  defmacro reply(response) do
    quote do
      [chan] = var!(message).args
      Kaguya.Util.sendPM(unquote(response), chan)
    end
  end

  @doc """
  Waits for an irc user to send a message which matches the given match string,
  and returns the resulting map. The user(s) listened for, channel listened for,
  timeout, and match params can all be tweaked. If the matcher times out,
  the variables new_message and resp will be set to nil, otherwise they will
  contain the message and the parameter map respectively for use.

  You must use await_resp in a match which has the asnyc: true
  flag enabled or the module will time out.
  ## Example:
  ```
  def handleOn(message, %{"target" => t, "repl" => r}) do
    reply "Fine."
    {msg, _resp} = await_resp t
    if msg != nil do
      reply r
    end
  end
  ```

  In this example, the bot will say "Fine." upon the function being run,
  and then wait for the user in the channel to say the target phrase.
  On doing so, the bot responds with the given reply.

  await_resp also can be called with certain options, these are:
  * match_group - regex to be used for matching parameters in the given string.
  By default this is `[a-zA-Z0-9]+`
  * nick - the user whose nick will be matched against in the callback. Use :any
  to allow for any nick to be matched against. By default, this will be the nick
  of the user who sent the currently processed messages
  * chan - the channel to be matched against. Use :any to allow any channel to be matched
  against. By default this is the channel where the currently processed message was sent from.
  * timeout - the timeout period for a message to be matched, in milliseconds. By default it is
  60000, or 60 seconds.
  """
  defmacro await_resp(match_str, opts \\ []) do
    match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")
    timeout = Keyword.get(opts, :timeout, 60000)
    quote bind_quoted: [opts: opts, timeout: timeout, match_str: match_str, match_group: match_group] do
      nick = Keyword.get(opts, :nick, var!(message).user.nick)
      [def_chan] = var!(message).args
      chan = Keyword.get(opts, :chan, def_chan)
      Kaguya.Module.await_resp(match_str, chan, nick, timeout, match_group)
    end
  end

  @doc """
  Actual function used to execute await_resp. The macro should be preferred
  most of the time, but the function can be used if necessary.
  """
  def await_resp(match_str, chan, nick, timeout, match_group) do
    f =
    if String.contains? match_str, [":", "~"] do
      re = match_str |> extract_vars(match_group) |> Macro.escape
      fn msg ->
        if (msg.args == [chan] or chan == :any) and (msg.user.nick == nick or nick == :any) do
          case Regex.named_captures(re, msg.trailing) do
            nil -> false
            res -> {true, {msg, res}}
          end
        else
          false
        end
      end
    else
      fn msg ->
        if match_str == msg.trailing and (msg.args == [chan] or chan == :any) and (msg.user.nick == nick or nick == :any) do
          {true, {msg, nil}}
        else
          false
        end
      end
    end

    try do
      GenServer.call(Kaguya.Module.Builtin, {:add_callback, f}, timeout)
    catch
      :exit, _ -> GenServer.cast(Kaguya.Module.Builtin, {:remove_callback, self})
      {nil, nil}
    end
  end
end
