defmodule Fact.FileNameFormat.Hash.V1Test do
  use ExUnit.Case

  alias Fact.FileNameFormat.Hash.V1

  @moduletag :capture_log

  doctest V1

  test "module exists" do
    assert is_list(V1.module_info())
  end

  describe "id/0" do
    test "should be :hash" do
      assert :hash === V1.id()
    end
  end

  describe "version/0" do
    test "should be 1" do
      assert 1 === V1.version()
    end
  end

  describe "metadata/0" do
    test "should default algorithm to :sha and encoding to :base16" do
      %{algorithm: algo, encoding: enc} = V1.metadata()
      assert :sha == algo
      assert :base16 == enc
    end
  end

  describe "init/1" do
    test "given empty map should return defaults" do
      %{algorithm: algo, encoding: enc} = V1.metadata()
      assert %V1{algorithm: algo, encoding: enc} == V1.init(%{})
    end

    test "can override algorithm, encoding will default" do
      %{encoding: encoding} = V1.metadata()
      assert %V1{algorithm: :blake2b, encoding: encoding} == V1.init(%{algorithm: :blake2b})
    end

    test "can override encoding, algoritm will default" do
      %{algorithm: algo} = V1.metadata()
      assert %V1{encoding: :base32, algorithm: algo} == V1.init(%{encoding: :base32})
    end

    test "given invalid algorithm, should" do
      assert {:error, {:invalid_algorithm, :bad}} == V1.init(%{algorithm: :bad})
    end

    test "given invalid encoding, should fail" do
      assert {:error, {:invalid_encoding, :bad}} == V1.init(%{encoding: :bad})
    end

    test "given invalid key, should fail" do
      assert {:error, {:unknown_option, :invalid}} == V1.init(%{invalid: :neat})
    end
  end

  describe "normalize_options/1" do
    test "given empty map should return empty map" do
      assert %{} == V1.normalize_options(%{})
    end

    test "given valid algorithm value as string, should convert to atom" do
      assert %{algorithm: :md5} == V1.normalize_options(%{algorithm: "md5"})
      assert %{algorithm: :sha} == V1.normalize_options(%{algorithm: "sha"})
      assert %{algorithm: :sha256} == V1.normalize_options(%{algorithm: "sha256"})
      assert %{algorithm: :sha512} == V1.normalize_options(%{algorithm: "sha512"})
      assert %{algorithm: :sha3_256} == V1.normalize_options(%{algorithm: "sha3_256"})
      assert %{algorithm: :sha3_512} == V1.normalize_options(%{algorithm: "sha3_512"})
      assert %{algorithm: :blake2b} == V1.normalize_options(%{algorithm: "blake2b"})
      assert %{algorithm: :blake2s} == V1.normalize_options(%{algorithm: "blake2s"})
    end

    test "given valid algorithm value as :atom, should succeed" do
      assert %{algorithm: :md5} == V1.normalize_options(%{algorithm: :md5})
      assert %{algorithm: :sha} == V1.normalize_options(%{algorithm: :sha})
      assert %{algorithm: :sha256} == V1.normalize_options(%{algorithm: :sha256})
      assert %{algorithm: :sha512} == V1.normalize_options(%{algorithm: :sha512})
      assert %{algorithm: :sha3_256} == V1.normalize_options(%{algorithm: :sha3_256})
      assert %{algorithm: :sha3_512} == V1.normalize_options(%{algorithm: :sha3_512})
      assert %{algorithm: :blake2b} == V1.normalize_options(%{algorithm: :blake2b})
      assert %{algorithm: :blake2s} == V1.normalize_options(%{algorithm: :blake2s})
    end

    test "given invalid algorithm values, should fail with :invalid_algorithm" do
      assert {:error, {:invalid_algorithm, "a bunch of gobley gook"}} ==
               V1.normalize_options(%{algorithm: "a bunch of gobley gook"})

      assert {:error, {:invalid_algorithm, 1}} == V1.normalize_options(%{algorithm: 1})
      assert {:error, {:invalid_algorithm, nil}} == V1.normalize_options(%{algorithm: nil})
    end

    test "given valid encoding value as string, should convert to atom" do
      assert %{encoding: :base16} == V1.normalize_options(%{encoding: "base16"})
      assert %{encoding: :base32} == V1.normalize_options(%{encoding: "base32"})
      assert %{encoding: :base64url} == V1.normalize_options(%{encoding: "base64url"})
    end

    test "given valid encoding value as :atom, should succeed" do
      assert %{encoding: :base16} == V1.normalize_options(%{encoding: :base16})
      assert %{encoding: :base32} == V1.normalize_options(%{encoding: :base32})
      assert %{encoding: :base64url} == V1.normalize_options(%{encoding: :base64url})
    end

    test "given invalid encoding values, should fail with :invalid_encoding" do
      assert {:error, {:invalid_encoding, "base64"}} ==
               V1.normalize_options(%{encoding: "base64"})

      assert {:error, {:invalid_encoding, 1}} == V1.normalize_options(%{encoding: 1})
      assert {:error, {:invalid_encoding, nil}} == V1.normalize_options(%{encoding: nil})
    end

    test "unknown keys should be removed" do
      assert %{algorithm: :sha, encoding: :base16} ==
               V1.normalize_options(%{algorithm: "sha", encoding: "base16", unknown: "something"})
    end
  end

  describe "for/2" do
    test "sha1 - base16" do
      sha1_base16 = V1.for(V1.init(%{algorithm: :sha, encoding: :base16}), "test")
      # A sha1 is 20-bytes, base16 encodes 4 bits to a byte, so this doubles the size to 40-bytes.
      assert 40 == String.length(sha1_base16)
    end

    test "sha1 - base32" do
      sha1_base32 = V1.for(V1.init(%{algorithm: :sha, encoding: :base32}), "test")
      # A sha1 is 20-bytes (160 bits), base32 encodes 5 bits to 1 byte. So this should be 32-bytes
      assert 32 == String.length(sha1_base32)
    end

    test "sha1 - base64url" do
      sha1_base64url = V1.for(V1.init(%{algorithm: :sha, encoding: :base64url}), "test")
      # A sha1 is 20-bytes (160 bits), base32 encodes 6 bits to 1 byte. 
      # So this would be 26 bytes with 4 bits remaining, so round up to 27 bytes.
      assert 27 == String.length(sha1_base64url)
    end

    test "manual construction of the struct with invalid algorithm should fail" do
      invalid_algo = %V1{algorithm: :sha384, encoding: :base32}
      assert {:error, {:invalid_algorithm, :sha384}} == V1.for(invalid_algo, "test")
    end

    test "manual construction of the struct with invalid encoding should fail" do
      invalid_algo = %V1{algorithm: :sha256, encoding: :base64}
      assert {:error, {:invalid_encoding, :base64}} == V1.for(invalid_algo, "test")
    end
  end
end
