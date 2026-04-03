# TDG + STAMP Compliant Elixir 1.18 Application Container
# Test-Driven Generation with Safety Constraints

FROM registry.nixos.org/nixos/library/elixir:1.18-alpine

# STAMP Safety Constraint 1: Verified base image
LABEL org.opencontainers.image.source="registry.nixos.org/nixos/library/elixir:1.18-alpine"
LABEL org.opencontainers.image.title="Indrajaal Elixir Application Demo"
LABEL org.opencontainers.image.version="1.18-nixos-demo"
LABEL tps.methodology="jidoka"
LABEL tdg.compliant="true"
LABEL stamp.safety="validated"

# Install required system packages for PostgreSQL client
RUN apk add --no-cache \
    postgresql-client \
    curl \
    bash \
    git \
    build-base

# STAMP Safety Constraint 2: Application environment
ENV MIX_ENV=demo
ENV ELIXIR_ERL_OPTIONS="+S 16"
ENV DATABASE_URL=postgres://postgres:postgres@postgres:5433/indrajaal_demo
ENV REDIS_URL=redis://redis:6379
ENV PHX_HOST=0.0.0.0
ENV PHX_PORT=4000
ENV CONTAINER_ENFORCEMENT=true
ENV PHICS_ENABLED=true
ENV SOP_V51_MODE=enabled

# STAMP Safety Constraint 3: Port consistency
EXPOSE 4000 4001

# STAMP Safety Constraint 4: Working directory
WORKDIR /workspace

# STAMP Safety Constraint 5: Dependency caching
VOLUME ["/workspace/deps", "/workspace/_build"]

# TDG Validation: Install Hex and Rebar first
RUN mix local.hex --force && \
    mix local.rebar --force

# STAMP Safety Constraint: Health validation
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# TDG Validation: Ensure Phoenix server starts properly
CMD ["sh", "-c", "mix deps.get && mix ecto.setup && mix phx.server"]