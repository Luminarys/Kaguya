defmodule Kaguya.Module do
  use Behaviour

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
        {:ok, {}}
      end

      defoverridable init: 1

      def handle_cast({:msg, message}, state) do
        require Logger
        Logger.log :debug, "Running module #{@module_name}'s dispatcher!"
        try do
          handle_message({:msg, message}, {true})
        rescue
          e in FunctionClauseError ->
            Logger.log :debug, "Message fell through for #{@module_name}!"
            {:noreply, state}
        end
      end
    end
  end

  defmacro handle(command, do: body) do
    quote do
      def handle_message({:msg, %{command: unquote(command)} = var!(message)}, state) do
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro match_all(function) do
    quote do
      unquote(function)(var!(message))
    end
  end

  defmacro match_re(re, function) do
    quote do
      if Regex.match?(unquote(re), var!(message).trailing) do
        unquote(function)(var!(message))
      end
    end
  end

  defmacro match(match_str, function) do
    re = match_str |> extract_vars |> Macro.escape
    if String.contains? match_str, [":", "~"] do
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

  defp extract_vars(match_str) do
    parts = String.split(match_str)
    l = for part <- parts, do: gen_part(part)
    expr = Enum.join(l, " ")
    Regex.compile!(expr)
  end

  defp gen_part(part) do
    case part do
      ":" <> param -> "(?<#{param}>[a-zA-Z0-9]+)"
      "~" <> param -> "(?<#{param}>.+)"
      text -> Regex.escape(text)
    end
  end

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

  defmacro validate(validator, do: body) do
    quote do
      if unquote(validator)(var!(message)) do
        unquote(body)
      end
    end
  end

  defmacro reply(response) do
    quote do
      [chan] = var!(message).args
      Kaguya.Util.sendPM(unquote(response), chan)
    end
  end
end
