defmodule Kaguya.Core.Message do
  @moduledoc """
  Representation of an IRC message in struct form.
  The trailing argument is the final argument, separated
  for convenience.
  """
  defstruct command: "", args: [], trailing: "", user: nil
end
