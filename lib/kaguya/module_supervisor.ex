defmodule Kaguya.ModuleSupervisor do
  use Supervisor
  require Logger

  @moduledoc """
  Module supervisor. It runs all modules specified in the :modules
  configuration option for :kaguya.
  """

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    Logger.log :debug, "Starting modules!"
    load_modules()
    |> Enum.map(fn module -> worker(module, []) end)
    |> supervise(strategy: :one_for_one)
  end

  defp load_modules do
    :code.get_path
    |> Enum.reduce([], fn path, modules ->
      {:ok, files} = :erl_prim_loader.list_dir(path |> to_char_list)
      [Enum.reduce(files, [], &match_module/2)|modules]
    end)
    |> List.flatten
  end

  @module_re ~r/(?<module>.*).Kaguya_Module.beam$/

  defp match_module(file, modules) do
    captures = Regex.named_captures(@module_re,  List.to_string(file))
    case captures do
      %{"module" => mod_name} ->
        mod = String.to_atom(mod_name)
        [mod|modules]
      nil -> modules
    end
  end
end
