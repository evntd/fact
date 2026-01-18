defmodule Fact.Seam.Storage.Registry do
  @moduledoc """
  Registry for `Fact.Seam.Storage` implementations.

  This module provides:

    * A list of all known storage implementations.
    * Resolution of a specific implementation by `{family, version}`.
    * Access to the latest version of a storage implementation for a given family.

  ## Usage

  Use this registry to:

    1. Retrieve all storage implementations via `all/0`.
    2. Resolve a specific implementation via `resolve/1` or `resolve/2`.
    3. Get the latest implementation or version for a given storage family.

  This registry currently contains the following implementation(s):

      * `Fact.Seam.Storage.Standard.V1`
  """
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.Storage.Standard.V1,
      Fact.Seam.Storage.Standard.V2
    ]
end
