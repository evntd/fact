defmodule Fact.Seam.FileName.Hash.V1Test do
  use ExUnit.Case, async: true

  alias Fact.Seam.FileName.Hash.V1

  describe "get/3" do
    test "produces a base16-encoded SHA hash" do
      state = %V1{algorithm: :sha, encoding: :base16}
      {:ok, name} = V1.get(state, "hello", [])

      expected = :crypto.hash(:sha, "hello") |> Base.encode16(case: :lower)
      assert name == expected
    end

    test "produces a base16-encoded SHA256 hash" do
      state = %V1{algorithm: :sha256, encoding: :base16}
      {:ok, name} = V1.get(state, "test data", [])

      expected = :crypto.hash(:sha256, "test data") |> Base.encode16(case: :lower)
      assert name == expected
    end

    test "produces a base32 hash" do
      state = %V1{algorithm: :sha, encoding: :base32}
      {:ok, name} = V1.get(state, "hello", [])

      expected = :crypto.hash(:sha, "hello") |> Base.encode32(case: :lower, padding: false)
      assert name == expected
    end

    test "produces a base64url hash" do
      state = %V1{algorithm: :sha256, encoding: :base64url}
      {:ok, name} = V1.get(state, "hello", [])

      expected = :crypto.hash(:sha256, "hello") |> Base.url_encode64(padding: false)
      assert name == expected
    end

    test "different inputs produce different names" do
      state = %V1{algorithm: :sha256, encoding: :base16}
      {:ok, a} = V1.get(state, "aaa", [])
      {:ok, b} = V1.get(state, "bbb", [])

      assert a != b
    end
  end

  test "default_options/0" do
    assert %{algorithm: :sha, encoding: :base16} = V1.default_options()
  end
end
