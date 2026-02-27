if Code.ensure_loaded?(AshPostgres.DataLayer) do
  defmodule AshObjectIds.Transformers.MigrationDefaults do
    @moduledoc """
    Sets PostgreSQL migration defaults for ObjectId primary key attributes.

    When `migration_default?` is enabled in the `object_id` DSL, this transformer
    adds `fragment("uuid_generate_v7()")` as the migration default for the primary
    key. This ensures UUIDs are generated database-side for raw SQL inserts and seeds.

    Requires the `AshObjectIds.PostgresExtension` to be installed in your repo.
    """
    use Spark.Dsl.Transformer

    alias Spark.Dsl.Transformer

    def transform(dsl_state) do
      data_layer = Transformer.get_persisted(dsl_state, :data_layer)

      dsl_state =
        if data_layer == AshPostgres.DataLayer do
          case AshObjectIds.Info.object_id_migration_default?(dsl_state) do
            {:ok, true} ->
              [pk] = Ash.Resource.Info.primary_key(dsl_state)

              migration_defaults =
                [{pk, "fragment(\"uuid_generate_v7()\")"}]
                |> Keyword.merge(
                  Transformer.get_option(dsl_state, [:postgres], :migration_defaults) || []
                )

              Transformer.set_option(dsl_state, [:postgres], :migration_defaults, migration_defaults)

            _ ->
              dsl_state
          end
        else
          dsl_state
        end

      {:ok, dsl_state}
    end
  end
end
