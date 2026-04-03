import os
import re

def repair_file(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # Replacements for common corrupted patterns
    replacements = [
        (r'\b__opts\b', 'opts'),
        (r'\b_tasks\b', 'tasks'),
        (r'\b_results\b', 'results'),
        (r'\b_load_tasks\b', 'load_tasks'),
        (r'\btest__data\b', 'test_data'),
        (r'\bprocessed__data\b', 'processed_data'),
        (r'\bmeta__data\b', 'metadata'),
        (r'\b__data\b', 'data'),
        (r'\b__event\b', 'event'),
        (r'\b__requirements\b', 'requirements'),
        (r'\b__result\b', 'result'),
        (r'\b__status\b', 'status'),
        # Fix specific cases where underscore was used for assignment but not for usage
        (r'(_tasks)\s*=\s*', 'tasks = '),
        (r'(_results)\s*=\s*', 'results = '),
        (r'(_load_tasks)\s*=\s*', 'load_tasks = '),
        (r'(_pid)\s*=\s*', 'pid = '), # Be careful with _pid if it is intentionally ignored
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

test_dir = "test/indrajaal/performance/"
for filename in os.listdir(test_dir):
    if filename.endswith("_test.exs"):
        repair_file(os.path.join(test_dir, filename))
