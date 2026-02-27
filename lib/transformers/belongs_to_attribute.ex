defmodule AshObjectIds.Transformers.BelongsToAttribute do
  @moduledoc """
  Automatically updates FK attributes with the correct ObjectId type for
  `belongs_to` relationships pointing to AshObjectIds resources.

  Without this transformer, users must manually specify:

      belongs_to :post, Post, attribute_type: Post.ObjectId

  With this transformer, the `attribute_type` is inferred automatically:

      belongs_to :post, Post  # attribute_type set to Post.ObjectId automatically

  ## Implementation Note

  This is registered as a transformer but conceptually acts as a post-processing
  step. It runs after Ash's `BelongsToAttribute` transformer has created the FK
  attributes, and after the `DefineType` persister has created ObjectId modules.

  For self-referential relationships, the ObjectId module is created by the
  `DefineType` persister in the same compilation unit.
  """
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    # No-op: FK attribute updates are now done in DefineType persister
    # to ensure ObjectId modules exist before we reference them.
    {:ok, dsl_state}
  end
end
