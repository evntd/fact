defmodule Fact.LedgerFileName do
  use Fact.Seam.FileName.Adapter,
    context: :ledger_file_name,
    allowed_impls: [{:fixed, 1}],
    fixed_options: %{
      {:fixed, 1} => %{name: ".ledger"}
    }

  def get(%Context{} = context) do
    get(context, nil)
  end
end
