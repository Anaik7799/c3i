{application,opentelemetry_finch,
             [{modules,['Elixir.OpentelemetryFinch']},
              {optional_applications,[]},
              {applications,[kernel,stdlib,elixir,logger,telemetry,
                             opentelemetry_api]},
              {description,"Trace Finch request with OpenTelemetry."},
              {registered,[]},
              {vsn,"0.2.0"}]}.
