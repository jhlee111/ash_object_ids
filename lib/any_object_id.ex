defmodule AshObjectIds.AnyObjectId do
  @moduledoc """
  A universal ObjectId type that accepts any prefixed object ID.

  This type is useful as a global replacement for `:uuid` when you want
  all UUID fields (including action arguments, non-AshObjectIds resources,
  and manual attributes) to accept prefixed IDs.

  ## Usage

  Register as a custom type in your Ash config:

      config :ash,
        custom_types: [uuid: AshObjectIds.AnyObjectId]

  This replaces the standard `Ash.Type.UUID` for all `:uuid` references,
  making them accept both prefixed IDs (`"user_CWzLBdFy2f1XhrtesFferY"`)
  and raw UUIDs (`"550e8400-e29b-41d4-a716-446655440000"`).

  ## Behavior

  - **Input**: Accepts any prefixed object ID or raw UUID string
  - **Storage**: Native PostgreSQL UUID binary (16 bytes)
  - **Output**: Returns the original prefixed form if available, otherwise
    the raw UUID string from the database
  """

  use Ash.Type

  @impl true
  def storage_type(_constraints), do: :uuid

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(input, _constraints) when is_binary(input) do
    case AshObjectIds.Type.decode_object_id(input) do
      {:ok, _prefix, _uuid} ->
        {:ok, input}

      _ ->
        # Fall back to standard UUID casting for raw UUIDs
        case Ecto.UUID.cast(input) do
          {:ok, _} -> {:ok, input}
          :error -> :error
        end
    end
  end

  def cast_input(_, _constraints), do: :error

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}

  def cast_stored(input, constraints) do
    Ash.Type.UUID.cast_stored(input, constraints)
  end

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}

  def dump_to_native(input, _constraints) when is_binary(input) do
    case AshObjectIds.Type.decode_object_id(input) do
      {:ok, _prefix, uuid_binary} ->
        {:ok, uuid_binary}

      _ ->
        # Fall back to standard UUID dumping
        Ecto.UUID.dump(input)
    end
  end

  def dump_to_native(_, _constraints), do: :error

  @impl true
  def generator(_constraints) do
    StreamData.repeatedly(fn ->
      Ecto.UUID.bingenerate() |> Ecto.UUID.cast!()
    end)
  end
end
