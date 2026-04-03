---
paths: test/**/*.exs
---

# Dual Property Testing Framework Rules

## CRITICAL: Generator Disambiguation (EP-GEN-014)

This project uses BOTH PropCheck AND ExUnitProperties. You MUST disambiguate generators.

### Required Imports Pattern:
```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, property: 3]

# MANDATORY aliases
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD
```

### Generator Usage:
- **PropCheck forall**: Use `PC.` prefix
  ```elixir
  forall x <- PC.integer() do
    # ...
  end
  ```

- **ExUnitProperties check all**: Use `SD.` prefix
  ```elixir
  check all(x <- SD.integer()) do
    # ...
  end
  ```

### Validation:
Run `mix validate.ep014` to check compliance.
