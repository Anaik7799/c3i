---
paths: test/support/factories/**/*.ex
---

# Factory Rules for Test Data

## Required Pattern (SC-FAC-*)

Use Ash.Changeset pattern, NOT ExMachina:

```elixir
defmodule Indrajaal.Test.Factories.DomainFactory do
  @moduledoc "Factory for Domain resources"

  import Indrajaal.Test.FactoryUtilities

  def build(:resource_name, attrs \\ %{}) do
    # Create parent resources FIRST
    parent = get_or_create_parent(attrs)

    default_attrs = %{
      id: Ash.UUID.generate(),
      name: "Test #{:rand.uniform(10000)}",
      parent_id: parent.id,
      # ... other defaults
    }

    Map.merge(default_attrs, attrs)
  end

  def create(:resource_name, attrs \\ %{}) do
    attrs
    |> build(:resource_name)
    |> then(&Ash.Changeset.for_create(Resource, :create, &1))
    |> Ash.create!()
  end
end
```

## Rules
- Factory for EVERY resource (SC-FAC-002)
- Create parents before children (SC-FAC-003)
- Import FactoryUtilities for helpers
- Use `Ash.UUID.generate()` for IDs
