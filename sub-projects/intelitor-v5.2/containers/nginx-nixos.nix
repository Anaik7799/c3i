# NixOS Nginx Container with Proper User Configuration
{ pkgs ? import <nixpkgs> {} }:

let
  # Import Tailscale Library
  ts = import ./lib/tailscale.nix { inherit pkgs; };

  # NixOS minimal container with Nginx
  nginxConfig = pkgs.writeText "nginx.conf" ''
    # Run as root user (NixOS container compatible)
    user root;
    worker_processes auto;
    
    error_log /var/log/nginx/error.log warn;
    pid /var/run/nginx.pid;
    
    events {
        worker_connections 1024;
        use epoll;
        multi_accept on;
    }
    
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        # Logging
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
        
        access_log /var/log/nginx/access.log main;
        
        # Performance settings
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
        
        # Upstream definitions
        upstream indrajaal_app {
            server indrajaal-app-demo:4000;
        }
        
        upstream grafana_backend {
            server indrajaal-grafana-demo:3000;
        }
        
        upstream prometheus_backend {
            server indrajaal-prometheus-demo:9090;
        }
        
        # Main server block
        server {
            listen 80;
            server_name localhost;
            
            # Security headers
            add_header X-Frame-Options DENY;
            add_header X-Content-Type-Options nosniff;
            add_header X-XSS-Protection "1; mode=block";
            
            # Main application
            location / {
                proxy_pass http://indrajaal_app;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_connect_timeout 30s;
                proxy_send_timeout 30s;
                proxy_read_timeout 30s;
            }
            
            # Grafana dashboard
            location /grafana/ {
                proxy_pass http://grafana_backend/;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            }
            
            # Prometheus metrics
            location /prometheus/ {
                proxy_pass http://prometheus_backend/;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            }
            
            # Health check endpoint
            location /health {
                access_log off;
                return 200 "nginx-proxy-healthy\n";
                add_header Content-Type text/plain;
            }
            
            # Status endpoint
            location /nginx-status {
                access_log off;
                return 200 "active";
                add_header Content-Type text/plain;
            }
        }
    }
  '';

  # Create log directories
  logDirs = pkgs.runCommand "nginx-log-dirs" {} ''
    mkdir -p $out/var/log/nginx
    mkdir -p $out/var/run
    chmod 755 $out/var/log/nginx
    chmod 755 $out/var/run
  '';

  # Nginx startup script
  # Renamed to docker-entrypoint to match pattern expected by wrapper
  startupScript = pkgs.writeScriptBin "docker-entrypoint" ''
    #!${pkgs.bash}/bin/bash
    
    # Create necessary directories
    mkdir -p /var/log/nginx
    mkdir -p /var/run
    
    # Set permissions
    chmod 755 /var/log/nginx
    chmod 755 /var/run
    
    # Test nginx configuration
    echo "Testing nginx configuration..."
    ${pkgs.nginx}/bin/nginx -t -c ${nginxConfig}
    
    if [ $? -eq 0 ]; then
        echo "Nginx configuration test passed"
        echo "Starting nginx with configuration: ${nginxConfig}"
        exec ${pkgs.nginx}/bin/nginx -g "daemon off;" -c ${nginxConfig}
    else
        echo "Nginx configuration test failed"
        exit 1
    fi
  '';

in pkgs.dockerTools.buildImage {
  name = "indrajaal-nginx-demo";
  tag = "nixos-devenv";
  
  contents = [
    pkgs.nginx 
    pkgs.bash 
    pkgs.coreutils
    pkgs.curl
    ts.package # Inject Tailscale
    logDirs
    startupScript # Include script in contents
  ];
  
  config = {
    # Use wrapped entrypoint
    Cmd = [ "${ts.wrap startupScript}/bin/entrypoint-with-tailscale" ];
    ExposedPorts = {
      "80/tcp" = {};
      "443/tcp" = {};
    };
    WorkingDir = "/";
    Env = [
      "PATH=${pkgs.nginx}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin"
      "NGINX_CONFIG=${nginxConfig}"
    ];
    Labels = {
      "org.opencontainers.image.title" = "Intelitor Nginx NixOS Demo";
      "org.opencontainers.image.version" = "nixos-devenv";
      "tps.methodology" = "jidoka";
      "tdg.compliant" = "true";
      "stamp.safety" = "validated";
    };
  };
}
