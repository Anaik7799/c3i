import os
import re

def repair_file(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # Precise replacements with word boundaries
    replacements = [
        (r'\b__opts\b', 'opts'),
        (r'\b__data\b', 'data'),
        (r'\b__event\b', 'event'),
        (r'\b__result\b', 'result'),
        (r'\b__status\b', 'status'),
        (r'\b__requirements\b', 'requirements'),
        (r'\btest__data\b', 'test_data'),
        (r'\bprocessed__data\b', 'processed_data'),
        (r'\bmeta__data\b', 'metadata'),
        
        # Fix the mistakes from the previous run
        (r'\btestpid\b', 'test_pid'),
        (r'\bloadtasks\b', 'load_tasks'),
        
        # Ensure consistency for common test patterns
        (r'\b_tasks\b', 'tasks'),
        (r'\b_results\b', 'results'),
        (r'\b_load_tasks\b', 'load_tasks'),
        (r'\b_opts\b', 'opts'),
        (r'\b_test_pid\b', 'test_pid'),
        (r'\b_test_data\b', 'test_data'),
        (r'\b_processed_data\b', 'processed_data'),
    ]

    new_content = content
    for pattern, repl in replacements:
        new_content = re.sub(pattern, repl, new_content)

    # Specific fix for Task.await_many(tasks, ...)
    # If tasks is used but might be _tasks elsewhere
    # (The above \b_tasks\b handles most of it)

    if new_content != content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Repaired: {file_path}")
    else:
        print(f"No changes: {file_path}")

test_dir = "test/indrajaal/performance/"
for filename in os.listdir(test_dir):
    if filename.endswith("_test.exs"):
        repair_file(os.path.join(test_dir, filename))
