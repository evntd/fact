defmodule Fact.IndexCheckpointFile.Name do
  use Fact.Seam.FileName.Adapter,
    context: :index_checkpoint_file_name,
    allowed_impls: [{:fixed, 1}],
    fixed_options: %{
      {:fixed, 1} => %{name: ".checkpoint"}
    }

  def get(%Context{} = context) do
    get(context, nil)
  end
end
