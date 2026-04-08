{ pkgs, ... }:

{
  # SIL-6 Heavy Inference Cell (Mojo/Gemma)
  # SOPv5.11 Implementation: SC-ML-001
  
  virtualisation.podman.enable = true;

  containers.intelitor-mojo = {
    image = "localhost/intelitor-mojo:latest";
    autoStart = true;
    ports = [ "11434:11434" ];
    
    config = { config, pkgs, ... }: {
      environment.systemPackages = [ pkgs.ollama ];
      
      systemd.services.ollama = {
        description = "Ollama Inference Server (Mojo Cell)";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.ollama}/bin/ollama serve";
          Restart = "always";
          # SC-CPU-GOV-005: Nice level for heavy ML tasks
          Nice = 10;
        };
      };
      
      networking.firewall.allowedTCPPorts = [ 11434 ];
    };
  };
}
