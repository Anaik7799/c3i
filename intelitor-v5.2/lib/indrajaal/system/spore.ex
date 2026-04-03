defmodule Indrajaal.System.Spore do
  @moduledoc """
  ## PANSPERMIA ENGINE (L7-UNIVERSE)
  Generates the genetic code required to replicate this Holon on a new substrate.

  **Mechanism**:
  - Emits a self-contained bash script.
  """

  require Logger

  def replicate do
    Logger.info("🍄 [SPORE] Emitting Galactic Spore...")

    :telemetry.execute(
      [:indrajaal, :system, :spore, :emission],
      %{timestamp: System.system_time(:millisecond)},
      %{hlc: Indrajaal.Time.HLC.new()}
    )

    """
    #!/bin/bash
    # INDRAJAAL SPORE v1.0
    git clone https://github.com/indrajaal/indrajaal-demo.git
    cd indrajaal-demo
    ./scripts/cluster/start_cluster.sh
    """
  end
end
