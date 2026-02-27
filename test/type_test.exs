defmodule AshObjectIds.TypeTest do
  use ExUnit.Case, async: true

  alias AshObjectIds.Type

  for type <- [Ash.Type.UUID, Ash.Type.UUIDv7] do
    test "cast_input with #{inspect(type)}" do
      assert {:ok, nil} = Type.cast_input(unquote(type), "user", nil, [])

      assert {:ok, "user_CWzLBdFy2f1XhrtesFferY"} =
               Type.cast_input(unquote(type), "user", "user_CWzLBdFy2f1XhrtesFferY", [])

      assert {:error, "incorrect object prefix"} =
               Type.cast_input(unquote(type), "post", "user_CWzLBdFy2f1XhrtesFferY", [])
    end

    test "cast_stored with #{inspect(type)}" do
      assert {:ok, nil} = Type.cast_stored(unquote(type), "user", nil, [])
      id = unquote(type).generator([]) |> Enum.take(1) |> hd()
      assert {:ok, "user_" <> _} = Type.cast_stored(unquote(type), "user", id, [])
    end

    test "dump_to_native with #{inspect(type)}" do
      # nil passes through
      assert {:ok, nil} = Type.dump_to_native(unquote(type), "user", nil, [])

      # valid object ID decodes to 16-byte binary
      id = Type.generate(unquote(type), "user", [])
      assert {:ok, binary} = Type.dump_to_native(unquote(type), "user", id, [])
      assert byte_size(binary) == 16

      # wrong prefix returns error
      assert :error = Type.dump_to_native(unquote(type), "post", id, [])

      # invalid input returns error
      assert :error = Type.dump_to_native(unquote(type), "user", "garbage", [])
    end

    test "equal? with #{inspect(type)}" do
      # nil equality
      assert Type.equal?("user", nil, nil)
      refute Type.equal?("user", nil, "user_CWzLBdFy2f1XhrtesFferY")
      refute Type.equal?("user", "user_CWzLBdFy2f1XhrtesFferY", nil)

      # same ID
      id = Type.generate(unquote(type), "user", [])
      assert Type.equal?("user", id, id)

      # different IDs
      id2 = Type.generate(unquote(type), "user", [])
      refute Type.equal?("user", id, id2)

      # same UUID with different prefixes should still be equal
      # (both decode to the same underlying UUID binary)
      id_user = Type.generate(unquote(type), "user", [])
      "user_" <> slug = id_user
      id_post = "post_" <> slug
      assert Type.equal?("user", id_user, id_post)
    end
  end

  test "dump_to_embedded preserves prefix via generated ObjectId" do
    alias AshObjectIds.Test.Resources.Post

    # Generate a post ID
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{title: "test"})
      |> Ash.create!()

    # dump_to_embedded should return the prefixed form
    assert {:ok, "post_" <> _} = Post.ObjectId.dump_to_embedded(post.id, [])
  end

  test "generated ObjectId equal?/2" do
    alias AshObjectIds.Test.Resources.Post

    id1 = Post.ObjectId.generator([]) |> Enum.take(1) |> hd()
    assert Post.ObjectId.equal?(id1, id1)
    id2 = Post.ObjectId.generator([]) |> Enum.take(1) |> hd()
    refute Post.ObjectId.equal?(id1, id2)
  end
end
