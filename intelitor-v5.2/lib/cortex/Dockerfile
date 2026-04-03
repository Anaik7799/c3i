# Indrajaal Cortex Service - Cognitive Plane (F#/.NET 10)
# SIL-6 Biomorphic Compliance: SC-NEURO-006 (F# ONLY)

FROM mcr.microsoft.com/dotnet/sdk:10.0-preview.1-noble AS build
WORKDIR /app

# Install native dependencies for Zenoh-CS
RUN apt-get update && apt-get install -y \
    curl \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy fsproj and restore as distinct layers
COPY src/Indrajaal.Cortex/*.fsproj ./src/Indrajaal.Cortex/
RUN dotnet restore src/Indrajaal.Cortex/Indrajaal.Cortex.fsproj

# Copy everything else and build
COPY . .
RUN dotnet publish src/Indrajaal.Cortex/Indrajaal.Cortex.fsproj -c Release -o out

# Build runtime image
FROM mcr.microsoft.com/dotnet/runtime:10.0-preview.1-noble
WORKDIR /app

# Install runtime dependencies for Zenoh-CS
RUN apt-get update && apt-get install -y \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/out .

# SC-NEURO-006 Enforcement: Ensure binary is compiled F#
ENTRYPOINT ["dotnet", "Indrajaal.Cortex.dll"]
