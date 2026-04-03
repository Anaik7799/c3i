import os

TARGET_FILES = [
    "lib/indrajaal/performance/enterprise_monitoring_analytics.ex",
    "lib/indrajaal/performance/sop_v51_cybernetic_integration.ex",
    "lib/indrajaal/performance/real_time_optimizer.ex",
    "lib/indrajaal/performance/memory_optimizer.ex",
    "lib/indrajaal/performance/network_optimizer.ex",
    "lib/indrajaal/performance/performance_optimization_orchestrator.ex",
    "lib/indrajaal/performance/query_optimizer_enhanced.ex",
    "lib/indrajaal/performance/query_optimizer.ex",
    "lib/indrajaal/performance/cache_manager.ex",
    "lib/indrajaal/performance/database_optimizer.ex",
    "lib/indrajaal/performance/dynamic_scaling_engine.ex",
    "lib/indrajaal/performance/thermal_manager.ex",
    "lib/indrajaal/performance/power_manager.ex",
    "lib/indrajaal/performance/ml_performance_engine.ex",
    "lib/indrajaal/performance/numa_optimizer.ex",
    "lib/indrajaal/performance/feature_engineering.ex",
    "lib/indrajaal/performance/tenant_isolation_engine.ex",
    "lib/indrajaal/performance/advanced_resource_manager.ex",
    "lib/indrajaal/performance/distributed_performance_coordinator.ex"
]

def to_camel_case(snake_str):
    components = snake_str.split('_')
    return ''.join(x.title() for x in components)

def align_files():
    # Read the template
    with open("performance_template.ex", "r") as f:
        protocol_template = f.read()

    for file_path in TARGET_FILES:
        filename = os.path.basename(file_path)
        module_name_snake = filename.replace(".ex", "")
        module_name = to_camel_case(module_name_snake)
        
        # Specific overrides
        if module_name_snake == "sop_v51_cybernetic_integration":
            module_name = "SOPv51CyberneticIntegration"
        elif module_name_snake == "ml_performance_engine":
            module_name = "MLPerformanceEngine"
        elif module_name_snake == "numa_optimizer":
            module_name = "NUMAOptimizer"
            
        print(f"Aligning {file_path} as {module_name}...")
        
        content = protocol_template.replace("{module_name}", module_name)
        
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        
        with open(file_path, "w") as f:
            f.write(content)

if __name__ == "__main__":
    align_files()
