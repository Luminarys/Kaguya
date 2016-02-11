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

      init_attrs()

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

      # Used to scan for valid modules on start
      defmodule Kaguya_Module do
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
      def handle_cast({:msg, _message}, state), do: {:noreply, state}

      def print_help(var!(message), %{"search_term" => term}) do
        import Kaguya.Util
        @match_docs
        |> Enum.filter(fn match_doc -> String.starts_with?(match_doc, "#{yellow}#{term}") end)
        |> Enum.map(&reply_priv_notice/1)
      end

      def print_help(var!(message)) do
        Enum.map(@match_docs, &reply_priv_notice/1)
      end
    end
  end

  defmacro init_attrs do
    Module.register_attribute __CALLER__.module,
      :match_docs, accumulate: true, persist: true

    Module.register_attribute __CALLER__.module,
      :handler_impls, accumulate: true, persist: true

    Module.register_attribute __CALLER__.module,
      :handlers, accumulate: true, persist: true
  end

  defp generate_privmsg_handler(body) do
    help_cmd = Application.get_env(:kaguya, :help_cmd, ".help")
    help_search = help_cmd <> " ~search_term"
    quote do
      def handle_cast({:msg, %{command: "PRIVMSG"} = var!(message)}, state) do
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
  defmacro handle("PRIVMSG", do: body), do: generate_privmsg_handler(body)

  defmacro handle(command, do: body) do
    quote do
      def handle_cast({:msg, %{command: unquote(command)} = var!(message)}, state) do
        unquote(body)
        {:noreply, state}
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
    add_handler_impl(function, __CALLER__.module, [])
    func_exec_ast = quote do: unquote(function)(var!(message))
    uniq? = Keyword.get(opts, :uniq, false)
    overrideable? = Keyword.get(opts, :overrideable, false)

    func_exec_ast
    |> check_async(Keyword.get(opts, :async, false))
    |> check_unique(function, uniq?, overrideable?)
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
    add_handler_impl(function, __CALLER__.module, [])

    func_exec_ast =
    if Keyword.get(opts, :capture, false) do
      quote do: unquote(function)(var!(message), res)
    else
      quote do: unquote(function)(var!(message))
    end

    uniq? = Keyword.get(opts, :uniq, false)
    overrideable? = Keyword.get(opts, :overrideable, false)

    func_exec_ast
    |> check_async(Keyword.get(opts, :async, false))
    |> check_unique(function, uniq?, overrideable?)
    |> add_re_matcher(re, Keyword.get(opts, :capture, false))
  end

  defp add_re_matcher(body, re, use_named_capture)

  defp add_re_matcher(body, re, true) do
    quote do
      case Regex.named_captures(unquote(re), var!(message).trailing) do
        nil -> :ok
        res -> unquote(body)
      end
    end
  end

  defp add_re_matcher(body, re, false) do
    quote do
      if Regex.match?(unquote(re), var!(message).trailing) do
        unquote(body)
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
    match ["!say ~msg", "!s ~msg"], :sayMessage
  end
  ```

  In this example, the geRand function will be called
  when a user sends a message to a channel saying something like
  `!rand 0 10`. If both parameters are strings, the genRand function
  will be passed the messages, and a map which will look like `%{low: 0, high: 10}`.
  Additionally the usage of a list allows for command aliases, in the second match.

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
  defmacro match(match, function, opts \\ [])

  defmacro match(match_str, function, opts) when is_bitstring(match_str) do
    make_match(match_str, function, opts, __CALLER__.module)
  end

  defmacro match(match_list, function, opts) when is_list(match_list) do
    for match <- match_list, do: make_match(match, function, opts, __CALLER__.module)
  end

  defp make_match(match_str, function, opts, module) do
    add_docs(match_str, module, opts)
    add_handler_impl(function, module, get_var_list(match_str))

    uniq? = Keyword.get(opts, :uniq, false)
    overrideable? = Keyword.get(opts, :overrideable, false)
    async? = Keyword.get(opts, :async, false)
    match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")

    match_str
    |> gen_match_func_call(function)
    |> check_unique(function, uniq?, overrideable?)
    |> check_async(async?)
    |> add_captures(match_str, match_group)
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

    command = get_doc_command_string(match_str)

    var_count = get_match_var_num(match_str)

    if var_count > 0 do
      match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")
      "#{yellow}#{command} #{gray}(vars matching #{match_group}) #{clear}#{desc}"
    else
      "#{yellow}#{command} #{clear}#{desc}"
    end
  end

  defp get_doc_command_string(match_str) do
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
  end

  defp get_var_list(match_str) do
    String.split(match_str)
    |> Enum.reduce([], fn(part, acc) ->
      case String.first(part) do
        ":" -> [String.lstrip(part, ?:)|acc]
        "~" -> [String.lstrip(part, ?~)|acc]
        _ -> acc
      end
    end)
  end

  defp add_handler_impl(name, module, vars) do
    Module.put_attribute(module, :handlers, {name, vars})
  end

  defp get_match_var_num(match_str) do
    String.split(match_str)
    |> Enum.reduce(0, fn part, acc ->
      case String.first(part) do
        ":" -> acc + 1
        _ -> acc
      end
    end)
  end

  defp gen_match_func_call(match_str, function) do
    if match_str |> get_var_list |> length > 0 do
      quote do
        unquote(function)(var!(message), res)
      end
    else
      quote do
        unquote(function)(var!(message))
      end
    end
  end

  defp check_unique(body, function, use_uniq?, overrideable?)

  defp check_unique(body, _function, false, _overrideable), do: body

  defp check_unique(body, function, uniq_type, overrideable?) do
    id_string = get_unique_table_id(function, uniq_type)
    create_unique_match(body, id_string, overrideable?)
  end

  defp get_unique_table_id(function, type) do
    fun_string = Atom.to_string(function)
    case type do
      true -> quote do: "#{unquote(fun_string)}_#{chan}_#{nick}"
      :chan -> quote do: "#{unquote(fun_string)}_#{chan}"
      :nick -> quote do: "#{unquote(fun_string)}_#{chan}_#{nick}"
    end
  end

  defp create_unique_match(body, id_string, overrideable?)

  defp create_unique_match(body, id_string, true) do
    quote do
      [chan] = var!(message).args
      %{nick: nick} = var!(message).user

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
  end

  defp create_unique_match(body, id_string, false) do
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

  defp check_async(body, async?)

  defp check_async(body, true) do
    quote do
      Task.start fn ->
        unquote(body)
      end
    end
  end

  defp check_async(body, false), do: body

  defp add_captures(body, match_str, match_group) do
    if match_str |> get_var_list |> length > 0 do
      add_regex_capture(match_str, match_group, body)
    else
      add_string_capture(match_str, body)
    end
  end

  defp add_regex_capture(match_str, match_group, body) do
    re = match_str |> extract_vars(match_group) |> Macro.escape
    quote do
      case Regex.named_captures(unquote(re), var!(message).trailing) do
        nil ->
          :ok
        res -> unquote(body)
      end
    end
  end

  defp add_string_capture(match_str, body) do
    quote do
      if var!(message).trailing == unquote(match_str) do
        unquote(body)
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

  defmacro defh({name, _line, nil}, do: body) do
    args = [quote do: var!(message)]
    make_defh_func(name, args, body)
  end

  defmacro defh({name, _line, [msg_arg]}, do: body) do
    args = [quote do: var!(message) = unquote(msg_arg)]
    make_defh_func(name, args, body)
  end

  defmacro defh({name, _line, [msg_arg|map_arg]}, do: body) do
    args = [quote(do: var!(message) = unquote(msg_arg)), map_arg]
    make_defh_func(name, args, body)
  end

  defp make_defh_func(name, args, body) do
    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(body)
        # Suppress unused message warning
        var!(message)
      end
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
  defmacro validator(name, do: body) when is_atom(body) do
    create_validator(name, [body])
  end

  defmacro validator(name, do: body) do
    {:__block__, [], funcs} = body
    create_validator(name, funcs)
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
      recip = Map.get(var!(message).user, :nick)
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
      recip = Map.get(var!(message).user, :nick)
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
    has_vars? = match_str |> get_var_list |> length > 0

    match_fun = get_match_fun(match_str, chan, nick, match_group, has_vars?)

    try do
      GenServer.call(Kaguya.Module.Builtin, {:add_callback, match_fun}, timeout)
    catch
      :exit, _ -> GenServer.cast(Kaguya.Module.Builtin, {:remove_callback, self})
      {nil, nil}
    end
  end

  defp get_match_fun(match_str, chan, nick, match_group, has_vars?)

  defp get_match_fun(match_str, chan, nick, match_group, true) do
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
  end

  defp get_match_fun(match_str, chan, nick, _match_group, false) do
    fn msg ->
      if match_str == msg.trailing and (msg.args == [chan] or chan == :any) and (msg.user.nick == nick or nick == :any) do
        {true, {msg, nil}}
      else
        false
      end
    end
  end
end
