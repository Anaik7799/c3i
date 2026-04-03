#!/usr/bin/env elixir

defmodule ParallelizationKubernetesDeployment do
  @moduledoc """
  Kubernetes Deployment Script for Revolutionary Maximum Parallelization Infrastructure

  This script deploys the complete parallelization system to Kubernetes with:
  - Auto-scaling configuration (HPA/VPA)
  - Comprehensive monitoring and observability
  - Security policies and RBAC
  - Service mesh integration
  - Multi-environment support
  """

  __require Logger

  @deployment_name "indrajaal-parallelization"
  @namespace "indrajaal-system"
  @chart_version "1.0.0"

  @spec main(term()) :: any()
  def main(args) do
    Logger.info("🚀 Starting Kubernetes deployment of Parallelization Infrastructure")

    case parse_args(args) do
      {:ok, options} ->
        execute_deployment(options)

      {:error, reason} ->
        Logger.error("❌ Invalid arguments: #{reason}")
        print_usage()
        System.halt(1)
    end
  end

  defp parse_args(args) do
    case OptionParser.parse(args,
           strict: [
             environment: :string,
             namespace: :string,
             replicas: :integer,
             auto_scaling: :boolean,
             monitoring: :boolean,
             service_mesh: :boolean,
             dry_run: :boolean,
             help: :boolean
           ],
           aliases: [
             e: :environment,
             n: :namespace,
             r: :replicas,
             h: :help
           ]
         ) do
      {options, [], []} ->
        if options[:help] do
          print_usage()
          System.halt(0)
        end

        {:ok,
         Enum.into(options, %{
           environment: options[:environment] || "production",
           namespace: options[:namespace] || @namespace,
           replicas: options[:replicas] || 3,
           auto_scaling: options[:auto_scaling] !== false,
           monitoring: options[:monitoring] !== false,
           service_mesh: options[:service_mesh] !== false,
           dry_run: options[:dry_run] || false
         })}

      {_, _, invalid} ->
        {:error, "Invalid options: #{inspect(invalid)}"}
    end
  end

  defp execute_deployment(options) do
    Logger.info("📋 Deployment Configuration:")
    Logger.info("  Environment: #{options.environment}")
    Logger.info("  Namespace: #{options.namespace}")
    Logger.info("  Replicas: #{options.replicas}")
    Logger.info("  Auto-scaling: #{options.auto_scaling}")
    Logger.info("  Monitoring: #{options.monitoring}")
    Logger.info("  Service Mesh: #{options.service_mesh}")
    Logger.info("  Dry Run: #{options.dry_run}")

    with :ok <- validate_pre__requisites(),
         :ok <- create_namespace(options),
         :ok <- deploy_core_infrastructure(options),
         :ok <- deploy_parallelization_engine(options),
         :ok <- setup_auto_scaling(options),
         :ok <- setup_monitoring(options),
         :ok <- setup_service_mesh(options),
         :ok <- validate_deployment(options) do
      Logger.info("✅ Kubernetes deployment completed successfully!")
      print_deployment_info(options)
    else
      {:error, reason} ->
        Logger.error("❌ Deployment failed: #{reason}")
        System.halt(1)
    end
  end

  defp validate_pre__requisites do
    Logger.info("🔍 Validating pre__requisites")

    with :ok <- check_kubectl(),
         :ok <- check_cluster_connection(),
         :ok <- check_permissions() do
      Logger.info("✅ Pre__requisites validated")
      :ok
    else
      error -> error
    end
  end

  defp check_kubectl do
    case System.cmd("kubectl", ["version", "--client", "--short"], stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("  ✓ kubectl is available")
        :ok

      {output, _} ->
        Logger.error("  ✗ kubectl not found: #{output}")
        {:error, "kubectl not available"}
    end
  end

  defp check_cluster_connection do
    case System.cmd("kubectl", ["cluster-info"], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("  ✓ Kubernetes cluster connection verified")
        Logger.debug("    #{String.trim(output)}")
        :ok

      {output, _} ->
        Logger.error("  ✗ Cannot connect to Kubernetes cluster: #{output}")
        {:error, "cluster connection failed"}
    end
  end

  defp check_permissions do
    case System.cmd("kubectl", ["auth", "can-i", "create", "deployments"], stderr_to_stdout: true) do
      {"yes\\n", 0} ->
        Logger.info("  ✓ Required permissions verified")
        :ok

      {output, _} ->
        Logger.error("  ✗ Insufficient permissions: #{output}")
        {:error, "insufficient permissions"}
    end
  end

  defp create_namespace(options) do
    Logger.info("📦 Creating namespace: #{options.namespace}")

    namespace_manifest = create_namespace_manifest(options.namespace)

    if options.dry_run do
      Logger.info("  [DRY RUN] Would create namespace")
      Logger.debug(namespace_manifest)
      :ok
    else
      case apply_manifest(namespace_manifest) do
        :ok ->
          Logger.info("  ✓ Namespace created/updated")
          :ok

        error ->
          error
      end
    end
  end

  defp create_namespace_manifest(namespace) do
    """
    apiVersion: v1
    kind: Namespace
    metadata:
      name: #{namespace}
      labels:
        name: #{namespace}
        component: parallelization-infrastructure
        managed-by: indrajaal-deployment-script
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: #{@deployment_name}-sa
      namespace: #{namespace}
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: #{@deployment_name}-role
    rules:
    - apiGroups: [""]
      resources: ["pods", "services", "endpoints"]
      verbs: ["get", "list", "watch"]
    - apiGroups: ["apps"]
      resources: ["deployments", "replicasets"]
      verbs: ["get", "list", "watch"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: #{@deployment_name}-binding
    subjects:
    - kind: ServiceAccount
      name: #{@deployment_name}-sa
      namespace: #{namespace}
    roleRef:
      kind: ClusterRole
      name: #{@deployment_name}-role
      apiGroup: rbac.authorization.k8s.io
    """
  end

  defp deploy_core_infrastructure(options) do
    Logger.info("🏗️ Deploying core infrastructure components")

    manifests = [
      create_configmap_manifest(options),
      create_secret_manifest(options),
      create_pdb_manifest(options)
    ]

    if options.dry_run do
      Logger.info("  [DRY RUN] Would deploy core infrastructure")

      Enum.each(manifests, fn manifest ->
        Logger.debug(manifest)
      end)

      :ok
    else
      Enum.reduce_while(manifests, :ok, fn manifest, :ok ->
        case apply_manifest(manifest) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp create_configmap_manifest(options) do
    """
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: #{@deployment_name}-config
      namespace: #{options.namespace}
    __data:
      PARALLELIZATION_MODE: "enterprise"
      MAX_AGENTS: "10000"
      RESOURCE_OPTIMIZATION: "enabled"
      PERFORMANCE_MONITORING: "true"
      GPU_ACCELERATION: "auto-detect"
      MULTI_CLOUD_SUPPORT: "enabled"
      LOG_LEVEL: "info"
      METRICS_ENABLED: "true"
      TRACING_ENABLED: "true"
    """
  end

  defp create_secret_manifest(options) do
    # In a real deployment, these would be proper secrets
    """
    apiVersion: v1
    kind: Secret
    metadata:
      name: #{@deployment_name}-secrets
      namespace: #{options.namespace}
    type: Opaque
    __data:
      api-key: #{Base.encode64("demo-api-key-#{System.unique_integer([:positive])}")}
      __database-url: #{Base.encode64("ecto://__user:pass@postgres:5432/indrajaal_parallelization")}
    """
  end

  defp create_pdb_manifest(options) do
    """
    apiVersion: policy/v1
    kind: PodDisruptionBudget
    metadata:
      name: #{@deployment_name}-pdb
      namespace: #{options.namespace}
    spec:
      minAvailable: #{max(1, div(options.replicas, 2))}
      selector:
        matchLabels:
          app: #{@deployment_name}
    """
  end

  defp deploy_parallelization_engine(options) do
    Logger.info("⚡ Deploying parallelization engine")

    manifests = [
      create_deployment_manifest(options),
      create_service_manifest(options),
      create_ingress_manifest(options)
    ]

    if options.dry_run do
      Logger.info("  [DRY RUN] Would deploy parallelization engine")

      Enum.each(manifests, fn manifest ->
        Logger.debug(manifest)
      end)

      :ok
    else
      Enum.reduce_while(manifests, :ok, fn manifest, :ok ->
        case apply_manifest(manifest) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp create_deployment_manifest(options) do
    """
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: #{@deployment_name}
      namespace: #{options.namespace}
      labels:
        app: #{@deployment_name}
        version: #{@chart_version}
        component: parallelization-engine
    spec:
      replicas: #{options.replicas}
      strategy:
        type: RollingUpdate
        rollingUpdate:
          maxUnavailable: 1
          maxSurge: 1
      selector:
        matchLabels:
          app: #{@deployment_name}
      template:
        metadata:
          labels:
            app: #{@deployment_name}
            version: #{@chart_version}
          annotations:
            prometheus.io/scrape: "true"
            prometheus.io/port: "8080"
            prometheus.io/path: "/metrics"
        spec:
          serviceAccountName: #{@deployment_name}-sa
          securityContext:
            fsGroup: 1000
            runAsUser: 1000
            runAsNonRoot: true
          containers:
          - name: parallelization-engine
            image: indrajaal/parallelization-engine:latest
            imagePullPolicy: IfNotPresent
            ports:
            - name: http
              containerPort: 4000
              protocol: TCP
            - name: metrics
              containerPort: 8080
              protocol: TCP
            - name: health
              containerPort: 9090
              protocol: TCP
            env:
            - name: KUBERNETES_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            envFrom:
            - configMapRef:
                name: #{@deployment_name}-config
            - secretRef:
                name: #{@deployment_name}-secrets
            resources:
              __requests:
                cpu: 1000m
                memory: 2Gi
              limits:
                cpu: 4000m
                memory: 8Gi
            livenessProbe:
              httpGet:
                path: /health
                port: health
              initialDelaySeconds: 30
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            readinessProbe:
              httpGet:
                path: /ready
                port: health
              initialDelaySeconds: 10
              periodSeconds: 5
              timeoutSeconds: 3
              failureThreshold: 2
            startupProbe:
              httpGet:
                path: /startup
                port: health
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 30
            volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache
          volumes:
          - name: tmp
            emptyDir: {}
          - name: cache
            emptyDir:
              sizeLimit: 1Gi
          affinity:
            podAntiAffinity:
              preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                podAffinityTerm:
                  labelSelector:
                    matchExpressions:
                    - key: app
                      operator: In
                      values:
                      - #{@deployment_name}
                  topologyKey: kubernetes.io/hostname
    """
  end

  defp create_service_manifest(options) do
    """
    apiVersion: v1
    kind: Service
    metadata:
      name: #{@deployment_name}
      namespace: #{options.namespace}
      labels:
        app: #{@deployment_name}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      type: ClusterIP
      ports:
      - name: http
        port: 80
        targetPort: http
        protocol: TCP
      - name: metrics
        port: 8080
        targetPort: metrics
        protocol: TCP
      selector:
        app: #{@deployment_name}
    """
  end

  defp create_ingress_manifest(options) do
    """
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: #{@deployment_name}
      namespace: #{options.namespace}
      annotations:
        kubernetes.io/ingress.class: "nginx"
        cert-manager.io/cluster-issuer: "letsencrypt-prod"
        nginx.ingress.kubernetes.io/rate-limit: "100"
        nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    spec:
      tls:
      - hosts:
        - parallelization.#{options.environment}.indrajaal.com
        secretName: #{@deployment_name}-tls
      rules:
      - host: parallelization.#{options.environment}.indrajaal.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: #{@deployment_name}
                port:
                  number: 80
    """
  end

  defp setup_auto_scaling(options) do
    if options.auto_scaling do
      Logger.info("📈 Setting up auto-scaling (HPA/VPA)")

      manifests = [
        create_hpa_manifest(options),
        create_vpa_manifest(options)
      ]

      if options.dry_run do
        Logger.info("  [DRY RUN] Would setup auto-scaling")

        Enum.each(manifests, fn manifest ->
          Logger.debug(manifest)
        end)

        :ok
      else
        Enum.reduce_while(manifests, :ok, fn manifest, :ok ->
          case apply_manifest(manifest) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)
      end
    else
      Logger.info("  ⏭️ Auto-scaling disabled")
      :ok
    end
  end

  defp create_hpa_manifest(options) do
    """
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    metadata:
      name: #{@deployment_name}-hpa
      namespace: #{options.namespace}
    spec:
      scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: #{@deployment_name}
      minReplicas: #{max(1, div(options.replicas, 2))}
      maxReplicas: #{options.replicas * 3}
      metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 70
      - type: Resource
        resource:
          name: memory
          target:
            type: Utilization
            averageUtilization: 80
      - type: Pods
        pods:
          metric:
            name: indrajaal_active_agents
          target:
            type: AverageValue
            averageValue: "1000"
      behavior:
        scaleUp:
          stabilizationWindowSeconds: 60
          policies:
          - type: Percent
            value: 50
            periodSeconds: 60
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
          - type: Percent
            value: 10
            periodSeconds: 60
    """
  end

  defp create_vpa_manifest(options) do
    """
    apiVersion: autoscaling.k8s.io/v1
    kind: VerticalPodAutoscaler
    metadata:
      name: #{@deployment_name}-vpa
      namespace: #{options.namespace}
    spec:
      targetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: #{@deployment_name}
      updatePolicy:
        updateMode: "Off"  # Recommendation only
      resourcePolicy:
        containerPolicies:
        - containerName: parallelization-engine
          minAllowed:
            cpu: 500m
            memory: 1Gi
          maxAllowed:
            cpu: 8000m
            memory: 16Gi
          controlledResources: ["cpu", "memory"]
    """
  end

  defp setup_monitoring(options) do
    if options.monitoring do
      Logger.info("📊 Setting up monitoring and observability")

      manifests = [
        create_service_monitor_manifest(options),
        create_grafana_dashboard_manifest(options),
        create_prometheus_rules_manifest(options)
      ]

      if options.dry_run do
        Logger.info("  [DRY RUN] Would setup monitoring")

        Enum.each(manifests, fn manifest ->
          Logger.debug(manifest)
        end)

        :ok
      else
        Enum.reduce_while(manifests, :ok, fn manifest, :ok ->
          case apply_manifest(manifest) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)
      end
    else
      Logger.info("  ⏭️ Monitoring disabled")
      :ok
    end
  end

  defp create_service_monitor_manifest(options) do
    """
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: #{@deployment_name}
      namespace: #{options.namespace}
      labels:
        app: #{@deployment_name}
    spec:
      selector:
        matchLabels:
          app: #{@deployment_name}
      endpoints:
      - port: metrics
        interval: 30s
        path: /metrics
        honorLabels: true
    """
  end

  defp create_grafana_dashboard_manifest(options) do
    dashboard_json = create_grafana_dashboard_json()

    """
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: #{@deployment_name}-dashboard
      namespace: #{options.namespace}
      labels:
        grafana_dashboard: "1"
        app: #{@deployment_name}
    __data:
      parallelization-dashboard.json: |
        #{dashboard_json}
    """
  end

  defp create_grafana_dashboard_json do
    Jason.encode!(
      %{
        dashboard: %{
          id: nil,
          title: "Indrajaal Parallelization Engine",
          tags: ["indrajaal", "parallelization", "performance"],
          timezone: "browser",
          panels: [
            %{
              id: 1,
              title: "Active Agents",
              type: "stat",
              targets: [
                %{
                  expr: "indrajaal_active_agents",
                  legendFormat: "Active Agents"
                }
              ],
              gridPos: %{h: 8, w: 12, x: 0, y: 0}
            },
            %{
              id: 2,
              title: "Task Throughput",
              type: "graph",
              targets: [
                %{
                  expr: "rate(indrajaal_tasks_completed_total[5m])",
                  legendFormat: "Tasks/sec"
                }
              ],
              gridPos: %{h: 8, w: 12, x: 12, y: 0}
            },
            %{
              id: 3,
              title: "Resource Utilization",
              type: "graph",
              targets: [
                %{
                  expr: "indrajaal_cpu_utilization",
                  legendFormat: "CPU %"
                },
                %{
                  expr: "indrajaal_memory_utilization",
                  legendFormat: "Memory %"
                }
              ],
              gridPos: %{h: 8, w: 24, x: 0, y: 8}
            }
          ],
          time: %{
            from: "now-1h",
            to: "now"
          },
          refresh: "5s"
        }
      },
      pretty: true
    )
  end

  defp create_prometheus_rules_manifest(options) do
    """
    apiVersion: monitoring.coreos.com/v1
    kind: PrometheusRule
    metadata:
      name: #{@deployment_name}-rules
      namespace: #{options.namespace}
      labels:
        app: #{@deployment_name}
    spec:
      groups:
      - name: parallelization.rules
        rules:
        - alert: HighAgentUtilization
          expr: indrajaal_active_agents / indrajaal_max_agents > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High agent utilization detected"
            description: "Agent utilization is above 90% for 5 minutes"

        - alert: LowTaskThroughput
          expr: rate(indrajaal_tasks_completed_total[5m]) < 100
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Low task throughput detected"
            description: "Task throughput is below 100 tasks/sec for 10 minutes"

        - alert: HighErrorRate
          expr: rate(indrajaal_errors_total[5m]) > 10
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "Error rate is above 10 errors/sec for 2 minutes"
    """
  end

  defp setup_service_mesh(options) do
    if options.service_mesh do
      Logger.info("🕸️ Setting up service mesh integration")

      manifests = [
        create_virtual_service_manifest(options),
        create_destination_rule_manifest(options),
        create_peer_authentication_manifest(options)
      ]

      if options.dry_run do
        Logger.info("  [DRY RUN] Would setup service mesh")

        Enum.each(manifests, fn manifest ->
          Logger.debug(manifest)
        end)

        :ok
      else
        Enum.reduce_while(manifests, :ok, fn manifest, :ok ->
          case apply_manifest(manifest) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)
      end
    else
      Logger.info("  ⏭️ Service mesh disabled")
      :ok
    end
  end

  defp create_virtual_service_manifest(options) do
    """
    apiVersion: networking.istio.io/v1beta1
    kind: VirtualService
    metadata:
      name: #{@deployment_name}
      namespace: #{options.namespace}
    spec:
      hosts:
      - #{@deployment_name}
      - parallelization.#{options.environment}.indrajaal.com
      http:
      - match:
        - uri:
            prefix: "/api"
        route:
        - destination:
            host: #{@deployment_name}
            port:
              number: 80
        fault:
          delay:
            percentage:
              value: 0.001
            fixedDelay: 5s
        timeout: 30s
        retries:
          attempts: 3
          perTryTimeout: 10s
    """
  end

  defp create_destination_rule_manifest(options) do
    """
    apiVersion: networking.istio.io/v1beta1
    kind: DestinationRule
    metadata:
      name: #{@deployment_name}
      namespace: #{options.namespace}
    spec:
      host: #{@deployment_name}
      trafficPolicy:
        connectionPool:
          tcp:
            maxConnections: 100
          http:
            http1MaxPendingRequests: 50
            maxRequestsPerConnection: 10
        loadBalancer:
          simple: LEAST_CONN
        outlierDetection:
          consecutive5xxErrors: 3
          interval: 30s
          baseEjectionTime: 30s
          maxEjectionPercent: 50
    """
  end

  defp create_peer_authentication_manifest(options) do
    """
    apiVersion: security.istio.io/v1beta1
    kind: PeerAuthentication
    metadata:
      name: #{@deployment_name}
      namespace: #{options.namespace}
    spec:
      selector:
        matchLabels:
          app: #{@deployment_name}
      mtls:
        mode: STRICT
    """
  end

  defp validate_deployment(options) do
    Logger.info("🔍 Validating deployment")

    if options.dry_run do
      Logger.info("  [DRY RUN] Skipping deployment validation")
      :ok
    else
      with :ok <- wait_for_deployment(options),
           :ok <- check_pod_health(options),
           :ok <- check_service_endpoints(options) do
        Logger.info("  ✓ Deployment validation successful")
        :ok
      else
        error -> error
      end
    end
  end

  defp wait_for_deployment(options) do
    Logger.info("  ⏳ Waiting for deployment to be ready...")

    case System.cmd(
           "kubectl",
           [
             "rollout",
             "status",
             "deployment/#{@deployment_name}",
             "-n",
             options.namespace,
             "--timeout=300s"
           ],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        Logger.info("    ✓ Deployment is ready")
        :ok

      {output, _} ->
        Logger.error("    ✗ Deployment failed to become ready: #{output}")
        {:error, "deployment not ready"}
    end
  end

  defp check_pod_health(options) do
    Logger.info("  🏥 Checking pod health...")

    case System.cmd(
           "kubectl",
           [
             "get",
             "pods",
             "-l",
             "app=#{@deployment_name}",
             "-n",
             options.namespace,
             "-o",
             "jsonpath={.items[*].status.phase}"
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        phases = String.split(String.trim(output), " ")

        if Enum.all?(phases, fn phase -> phase == "Running" end) do
          Logger.info("    ✓ All pods are running")
          :ok
        else
          Logger.error("    ✗ Some pods are not running: #{inspect(phases)}")
          {:error, "pods not healthy"}
        end

      {output, _} ->
        Logger.error("    ✗ Failed to check pod health: #{output}")
        {:error, "pod health check failed"}
    end
  end

  defp check_service_endpoints(options) do
    Logger.info("  🌐 Checking service endpoints...")

    case System.cmd(
           "kubectl",
           [
             "get",
             "endpoints",
             @deployment_name,
             "-n",
             options.namespace,
             "-o",
             "jsonpath={.subsets[*].addresses[*].ip}"
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        endpoints = String.split(String.trim(output), " ")

        if length(endpoints) > 0 do
          Logger.info("    ✓ Service endpoints are available (#{length(endpoints)} endpoints)")
          :ok
        else
          Logger.error("    ✗ No service endpoints available")
          {:error, "no service endpoints"}
        end

      {output, _} ->
        Logger.error("    ✗ Failed to check service endpoints: #{output}")
        {:error, "endpoint check failed"}
    end
  end

  defp apply_manifest(manifest) do
    case System.cmd("kubectl", ["apply", "-f", "-"], input: manifest, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, _} ->
        Logger.error("Failed to apply manifest: #{output}")
        {:error, "manifest application failed"}
    end
  end

  defp print_deployment_info(options) do
    Logger.info("")
    Logger.info("🎉 Deployment Information:")
    Logger.info("  Deployment Name: #{@deployment_name}")
    Logger.info("  Namespace: #{options.namespace}")
    Logger.info("  Environment: #{options.environment}")
    Logger.info("  Replicas: #{options.replicas}")
    Logger.info("")
    Logger.info("📋 Useful Commands:")
    Logger.info("  Check status: kubectl get all -n #{options.namespace}")
    Logger.info("  View logs: kubectl logs -l app=#{@deployment_name} -n #{options.namespace}")

    Logger.info(
      "  Port forward: kubectl port-forward svc/#{@deployment_name} 8080:80 -n #{options.namespace}"
    )

    Logger.info(
      "  Scale: kubectl scale deployment #{@deployment_name} --replicas=5 -n #{options.namespace}"
    )

    Logger.info("")
    Logger.info("🌐 Access URLs:")
    Logger.info("  Service: http://parallelization.#{options.environment}.indrajaal.com")
    Logger.info("  Metrics: http://parallelization.#{options.environment}.indrajaal.com/metrics")
    Logger.info("  Health: http://parallelization.#{options.environment}.indrajaal.com/health")
  end

  defp print_usage do
    IO.puts("""
    Kubernetes Deployment Script for Indrajaal Parallelization Infrastructure

    Usage: #{Path.basename(__ENV__.file)} [OPTIONS]

    Options:
      -e, --environment ENV     Deployment environment (default: production)
      -n, --namespace NAMESPACE Kubernetes namespace (default: #{@namespace})
      -r, --replicas COUNT      Number of replicas (default: 3)
      --auto-scaling           Enable auto-scaling (HPA/VPA) (default: true)
      --monitoring             Enable monitoring setup (default: true)
      --service-mesh           Enable service mesh integration (default: true)
      --dry-run                Show what would be deployed without applying
      -h, --help               Show this help message

    Examples:
      #{Path.basename(__ENV__.file)}                                    # Deploy with defaults
      #{Path.basename(__ENV__.file)} -e staging -r 2                   # Deploy to staging with 2 replicas
      #{Path.basename(__ENV__.file)} --dry-run                         # Show deployment manifests
      #{Path.basename(__ENV__.file)} -n custom-ns --no-auto-scaling    # Custom namespace, no auto-scaling
    """)
  end
end

# Run the deployment script
ParallelizationKubernetesDeployment.main(System.argv())
