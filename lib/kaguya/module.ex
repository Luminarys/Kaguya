defmodule Kaguya.Module do
  use Behaviour

  @moduledoc """
  When  this module is used, it will create wrapper
  functions which allow it to be automatically registered
  as a module and include all macros. It can be included like:
  `use Kaguya.Module, "module name here"`
  """

  defmacro __using__(module_name) do
    quote bind_quoted: [module_name: module_name] do
      use GenServer
      import Kaguya.Module

      @module_name module_name
      @task_table String.to_atom("#{@module_name}_tasks")
      @before_compile Kaguya.Module

      Module.register_attribute __MODULE__,
        :match_docs, accumulate: true, persist: true

      def start_link(opts \\ []) do
        {:ok, _pid} = GenServer.start_link(__MODULE__, :ok, [])
      end

      defoverridable start_link: 1

      def init(:ok) do
        require Logger
        Logger.log :debug, "Started module #{@module_name}!"
        :pg2.join(:modules, self)
        table_name = String.to_atom "#{@module_name}_tasks"
        :ets.new(@task_table, [:set, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}])
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
          FunctionClauseError ->
            Logger.log :debug, "Message fell through for #{@module_name}!"
            {:noreply, state}
        end
      end
    end
  end

  defmacro __before_compile__(env) do
    help_cmd = Application.get_env(:kaguya, :help_cmd, ".help")
    help_search = help_cmd <> " ~search_term"

    if env.module == Kaguya.Module.Builtin do
      add_docs(help_search, env.module, [doc: "Displays all commands which match the supplied prefix."])
      add_docs(help_cmd, env.module, [doc: "Displays this message."])
    end

    quote do
      def print_help(var!(message), %{"search_term" => term}) do
        import Kaguya.Util
        @match_docs
        |> Enum.filter(fn match_doc -> String.starts_with?(match_doc, "#{yellow}#{term}") end)
        |> Enum.map(fn match_doc -> reply_notice(match_doc) end)
      end

      def print_help(var!(message)) do
        Enum.map(@match_docs, fn match_doc -> reply_notice(match_doc) end)
      end
    end
  end

  def generate_privmsg_handler(body \\ nil) do
    help_cmd = Application.get_env(:kaguya, :help_cmd, ".help")
    help_search = help_cmd <> " ~search_term"
    quote do
      def handle_message({:msg, %{command: "PRIVMSG"} = var!(message)}, state) do
        unquote(body)

        match unquote(help_cmd), :print_help, nodoc: true
        match unquote(help_search), :print_help, nodoc: true

        {:noreply, state}
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
    if command == "PRIVMSG" do
      generate_privmsg_handler(body)
    else
      quote do
        def handle_message({:msg, %{command: unquote(command)} = var!(message)}, state) do
          unquote(body)
          {:noreply, state}
        end
      end
    end
  end

  @doc """
  Defines a matcher which always calls its corresponding
  function. Example: `match_all :pingHandler`

  The available options are:
  * async - runs the matcher asynchronously when this is true
  * uniq - ensures only one version of the matcher can be running per channel.
  Should be used with async: true.
  """
  defmacro match_all(function, opts \\ []) do
    func_exec_ast = quote do: unquote(function)(var!(message))

    func_exec_ast
    |> check_async(opts)
    |> check_unique(function, opts)
  end

  @doc """
  Defines a matcher which will match a regex againt the trailing portion
  of an IRC message. Example: `match_re ~r"me|you", :meOrYouHandler`

  The available options are:
  * async - runs the matcher asynchronously when this is true
  * uniq - ensures only one version of the matcher can be running per channel.
  Should be used with async: true.
  * capture - if true, then the regex will be matched as a named captures,
  and the specified function will be called with the message and resulting
  map on successful match. By default this option is false.
  """
  defmacro match_re(re, function, opts \\ []) do
    if Keyword.get(opts, :capture, false) do
      func_exec_ast = quote do: unquote(function)(var!(message), res)
    else
      func_exec_ast = quote do: unquote(function)(var!(message))
    end

    func_exec_ast
    |> check_async(opts)
    |> check_unique(function, opts)
    |> add_re_matcher(re, opts)
  end

  defp add_re_matcher(body, re, opts) do
    if Keyword.get(opts, :capture, false) do
      quote do
        case Regex.named_captures(unquote(re), var!(message).trailing) do
          nil -> :ok
          res -> unquote(body)
        end
      end
    else
      quote do
        if Regex.match?(unquote(re), var!(message).trailing) do
          unquote(body)
        end
      end
    end
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
  * uniq - When used with the async option, this ensures only one version of the matcher
  can be running at any given time. The uniq option can be either channel level or nick level,
  specified with the option :chan or :nick.
  * uniq_overridable - This is used to determine whether or not a unique match can be overriden
  by a new match, or if the new match should exit and allow the previous match to continue running.
  By default it is true, and new matches will kill off old matches.
  """
  defmacro match(match_str, function, opts \\ []) do
    add_docs(match_str, __CALLER__.module, opts)
    match_str
    |> gen_match_func_call(function)
    |> check_unique(function, opts)
    |> check_async(opts)
    |> add_captures(match_str, opts)
  end

  defp add_docs(match_str, module, opts) do
    if !Keyword.has_key?(opts, :nodoc) do
      doc_string = make_docstring(match_str, opts)
      Module.put_attribute(module, :match_docs, doc_string)
    end
  end

  defp make_docstring(match_str, opts) do
    import Kaguya.Util

    desc = Keyword.get(opts, :doc, "")

    command =
    String.split(match_str)
    |> Enum.map(fn part ->
      case String.first(part) do
        ":" ->
          var_name = String.lstrip(part, ?:)
          "<#{var_name}>"
        "~" ->
          var_name = String.lstrip(part, ?~)
          "<#{var_name}...>"
        _ -> part
      end
    end)
    |> Enum.join(" ")

    var_count =
    String.split(match_str)
    |> Enum.reduce(0, fn part, acc ->
      case String.first(part) do
        ":" -> acc + 1
        _ -> acc
      end
    end)

    if var_count > 0 do
      match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")
      "#{yellow}#{command} #{gray}(vars matching #{match_group}) #{clear}#{desc}"
    else
      "#{yellow}#{command} #{clear}#{desc}"
    end
  end

  defp gen_match_func_call(match_str, function) do
    if String.contains? match_str, [":", "~"] do
      quote do
        unquote(function)(var!(message), res)
      end
    else
      quote do
        unquote(function)(var!(message))
      end
    end
  end

  defp check_unique(body, function, opts) do
    fun_string = Atom.to_string(function)
    if Keyword.has_key?(opts, :uniq) do
      id_string =
      case Keyword.get(opts, :uniq) do
        true -> quote do: "#{unquote(fun_string)}_#{chan}_#{nick}"
        :chan -> quote do: "#{unquote(fun_string)}_#{chan}"
        :nick -> quote do: "#{unquote(fun_string)}_#{chan}_#{nick}"
      end
      if Keyword.get(opts, :uniq_overridable, true) do
        quote do
          [chan] = var!(message).args
          %{nick: nick} = var!(message).user

          IO.puts unquote(id_string)
          case :ets.lookup(@task_table, unquote(id_string)) do
            [{_fun, pid}] ->
              Process.exit(pid, :kill)
              :ets.delete(@task_table, unquote(id_string))
            [] -> nil
          end
          :ets.insert(@task_table, {unquote(id_string), self})
          unquote(body)
          :ets.delete(@task_table, unquote(id_string))
        end
      else
        quote do
          [chan] = var!(message).args
          %{nick: nick} = var!(message).user
           case :ets.lookup(@task_table, unquote(id_string)) do
            [{_fun, pid}] -> nil
            [] ->
              :ets.insert(@task_table, {unquote(id_string), self})
              unquote(body)
              :ets.delete(@task_table, unquote(id_string))
          end
        end
      end
    else
      body
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

  defp add_captures(body, match_str, opts) do
    match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")
    re = match_str |> extract_vars(match_group) |> Macro.escape
    if String.contains? match_str, [":", "~"] do
      quote do
        case Regex.named_captures(unquote(re), var!(message).trailing) do
          nil -> :ok
          res -> unquote(body)
        end
      end
    else
      quote do
        if var!(message).trailing == unquote(match_str) do
          unquote(body)
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
      recip = get_recip(var!(message))
      Kaguya.Util.sendPM(unquote(response), recip)
    end
  end

  @doc """
  Sends a response to the sender of the PRIVMSG with a given message via a private message.
  Example: `reply_priv "Hi"`
  """
  defmacro reply_priv(response) do
    quote do
      recip = Map.get(var!(message.user), :nick)
      Kaguya.Util.sendPM(unquote(response), recip)
    end
  end

  @doc """
  Sends a response to the sender of the PRIVMSG with a given message via a private message.
  Example: `reply_priv "Hi"`
  """
  defmacro reply_notice(response) do
    quote do
      recip = Kaguya.Module.get_recip(var!(message))
      Kaguya.Util.sendNotice(unquote(response), recip)
    end
  end

  @doc """
  Sends a response to the user who sent the PRIVMSG with a given message via a private message.
  Example: `reply_priv "Hi"`
  """
  defmacro reply_priv_notice(response) do
    quote do
      recip = Map.get(var!(message.user), :nick)
      Kaguya.Util.sendNotice(unquote(response), recip)
    end
  end

  @doc """
  Determines whether or not a response should be sent back to a channel
  or if the recipient sent the message in a PM
  """
  def get_recip(message) do
    [chan] = message.args
    bot = Application.get_env(:kaguya, :bot_name)
    case chan do
      ^bot -> Map.get(message.user, :nick)
      _ -> chan
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
  ## Example
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
      re = match_str |> extract_vars(match_group)
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
