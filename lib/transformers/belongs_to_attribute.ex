defmodule AshObjectIds.Transformers.BelongsToAttribute do
  @moduledoc """
  Automatically creates FK attributes with the correct ObjectId type for
  `belongs_to` relationships pointing to AshObjectIds resources.

  Without this transformer, users must manually specify:

      belongs_to :post, Post, attribute_type: Post.ObjectId

  With this transformer, the `attribute_type` is inferred automatically:

      belongs_to :post, Post  # attribute_type set to Post.ObjectId automatically
  """
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:relationships])
    |> Enum.filter(&(&1.type == :belongs_to && &1.define_attribute?))
    |> Enum.reject(&already_has_attribute?(dsl_state, &1))
    |> Enum.reduce_while({:ok, dsl_state}, fn relationship, {:ok, dsl_state} ->
      case resolve_object_id_type(dsl_state, relationship) do
        {:ok, object_id_type} ->
          attribute_opts = [
            name: relationship.source_attribute,
            type: object_id_type,
            allow_nil?:
              if(relationship.primary_key?, do: false, else: relationship.allow_nil?),
            writable?: relationship.attribute_writable?,
            public?: relationship.attribute_public?,
            primary_key?: relationship.primary_key?
          ]

          case Transformer.build_entity(
                 Ash.Resource.Dsl,
                 [:attributes],
                 :attribute,
                 attribute_opts
               ) do
            {:ok, attribute} ->
              {:cont,
               {:ok,
                Transformer.add_entity(dsl_state, [:attributes], attribute, type: :append)}}

            {:error, error} ->
              {:halt,
               {:error,
                Spark.Error.DslError.exception(
                  message:
                    "Could not create attribute for belongs_to #{relationship.name}: #{inspect(error)}",
                  path: [:relationships, relationship.name]
                )}}
          end

        :not_object_id ->
          # Destination doesn't use AshObjectIds — let Ash's default transformer handle it
          {:cont, {:ok, dsl_state}}
      end
    end)
  end

  defp already_has_attribute?(dsl_state, relationship) do
    dsl_state
    |> Transformer.get_entities([:attributes])
    |> Enum.any?(&(&1.name == relationship.source_attribute))
  end

  defp resolve_object_id_type(dsl_state, relationship) do
    source_module = Transformer.get_persisted(dsl_state, :module)

    destination_dsl_state =
      if relationship.destination != source_module do
        relationship.destination.spark_dsl_config()
      else
        dsl_state
      end

    # Check if the destination resource uses AshObjectIds
    case AshObjectIds.Info.object_id_prefix(destination_dsl_state) do
      {:ok, _prefix} ->
        # The destination uses AshObjectIds — use its generated ObjectId type
        object_id_type = Module.concat(relationship.destination, ObjectId)
        {:ok, object_id_type}

      _ ->
        :not_object_id
    end
  end

  # Run after BelongsToSourceField sets the source_attribute
  def after?(Ash.Resource.Transformers.BelongsToSourceField), do: true
  def after?(_), do: false

  # Run before Ash's BelongsToAttribute so we create the attribute first
  def before?(Ash.Resource.Transformers.BelongsToAttribute), do: true
  def before?(Ash.Resource.Transformers.ValidateRelationshipAttributes), do: true
  def before?(_), do: false
end
