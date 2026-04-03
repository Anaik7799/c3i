import os
import re

def repair_file(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # Precise replacements with word boundaries
    replacements = [
        (r'\b_performanceresults\b', 'performance_results'),
        (r'\b_performance_data\b', 'performance_data'),
        (r'\b__context\b', 'context'),
        (r'\b_tasks\b', 'tasks'),
        (r'\b_results\b', 'results'),
        (r'\b_opts\b', 'opts'),
        (r'\b_status\b', 'status'),
        (r'\b_config\b', 'config'),
        (r'\b_pid\b', 'pid'),
    ]

    new_content = content
    for pattern, repl in replacements:
        new_content = re.sub(pattern, repl, new_content)

    if new_content != content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Repaired: {file_path}")
    else:
        print(f"No changes: {file_path}")

repair_file("test/indrajaal/performance/dynamic_performance_optimization_test.exs")
