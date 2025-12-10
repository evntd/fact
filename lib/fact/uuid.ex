defmodule Fact.Uuid do
  @moduledoc false

  def v4() do
    :uuid.get_v4()
    |> :uuid.uuid_to_string(:nodash)
    |> to_string()
  end

  def valid?(uuid) do
    try do
      uuid
      |> :uuid.string_to_uuid()
      |> :uuid.is_uuid()
    catch
      :exit, :badarg -> false
    end
  end
end
