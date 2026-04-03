defmodule Indrajaal.BaseDomain do
  @moduledoc """
  Base domain module providing common configuration for all Ash domains.

  Includes:
  - Standard extensions (Admin, GraphQL, JSON API)
  - Authorization defaults
  - API configuration
  """

  defmacro __using__(opts) do
    name = Keyword.get(opts, :name, "domain")

    quote do
      use Ash.Domain,
        extensions: [
          AshAdmin.Domain,
          AshGraphql.Domain,
          AshJsonApi.Domain
        ]

      @domain_name unquote(name)

      authorization do
        require_actor? true
        authorize :by_default
      end

      json_api do
        prefix "/api / v1/#{@domain_name}"

        open_api do
          tag(@domain_name)
          group_by(:resource)
        end
      end

      graphql do
        root_level_errors?(false)
        authorize? true

        queries do
          # Default queries will be defined per resource
        end

        mutations do
          # Default mutations will be defined per resource
        end
      end

      admin do
        show?(true)
      end
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
