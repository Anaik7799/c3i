[
  # Dialyzer ignore patterns for Indrajaal Security Platform
  # Format: {file_pattern, line_or_function, warning_type}

  # Third-party library issues (ignore these until libraries are updated)
  {"deps/", :_, :_},
  {"_build/", :_, :_},

  # Phoenix generated files
  {"lib/indrajaal_web/endpoint.ex", :_, :unknown_function},
  {"lib/indrajaal_web/router.ex", :_, :unknown_function},

  # Ash framework internal warnings (acceptable)
  {:_, :_, {:unknown_function, {:ash, :_, :_}}},
  {:_, :_, {:unknown_function, {:ash_postgres, :_, :_}}},
  {:_, :_, {:unknown_function, {:ash_phoenix, :_, :_}}},
  {:_, :_, {:unknown_function, {"Spark.Dsl.Extension", :run_transformers, 4}}},
  {:_, :_, {:unknown_function, {"Spark.Dsl.Transformer", :sort, 1}}},
  {:_, :_, {:unknown_function, {"Spark.Error.DslError", :exception, 1}}},

  # Ash Query macro issues (already fixed with require)
  {:_, :_, {:call_to_missing, {"Ash.Query", :filter, 2}}},

  # ExMachina factory warnings (test-only code)
  {"test/support/factory.ex", :_, :_},
  {"test/support/factories/", :_, :_},

  # Test helper warnings (acceptable in test environment)
  {"test/support/", :_, :pattern_match},
  {"test/support/", :_, :unused_variable},

  # Mix tasks warnings (development tools)
  {"lib/mix/tasks/", :_, :no_return},
  {"lib/mix/tasks/", :_, :unused_fun},
  {"lib/mix/tasks/", :_, :contract_supertype},
  {"lib/mix/tasks/", :_, :guard_fail},
  {"lib/mix/tasks/", :_, :unmatched_return},

  # Configuration files (runtime configuration)
  {"config/", :_, :_},
  {"priv/", :_, :_}
]
