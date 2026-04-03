import os
import re

def enable_module(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()

    new_lines = []
    in_false_block = False
    skip_next_end = False
    
    # Simple heuristic: find the first "if false do" and the last "end" before the module's final "end"
    
    content = "".join(lines)
    # Match: if false do (anything) end (newline) end
    # We want to remove the 'if false do' and the matching 'end'.
    # Since these are mostly stubs, they usually have one big if false block.
    
    # Let's try a more robust way: remove the specific lines
    # Find index of 'if false do'
    start_idx = -1
    for i, line in enumerate(lines):
        if "if false do" in line:
            start_idx = i
            break
            
    if start_idx != -1:
        # Find the last 'end' that is NOT the module end
        # The module end is usually the last line
        end_idx = -1
        for i in range(len(lines) - 1, start_idx, -1):
            if lines[i].strip() == "end":
                # Check if there is another "end" after this one (the module end)
                has_later_end = False
                for j in range(i + 1, len(lines)):
                    if lines[j].strip() == "end":
                        has_later_end = True
                        break
                if has_later_end:
                    end_idx = i
                    break
        
        if end_idx != -1:
            # Remove start and end lines
            for i, line in enumerate(lines):
                if i == start_idx or i == end_idx:
                    continue
                new_lines.append(line)
            
            with open(file_path, 'w') as f:
                f.writelines(new_lines)
            print(f"Enabled: {file_path}")
        else:
            print(f"Could not find matching end for: {file_path}")
    else:
        print(f"No 'if false do' found in: {file_path}")

performance_dir = "lib/indrajaal/performance/"
for filename in os.listdir(performance_dir):
    if filename.endswith(".ex"):
        enable_module(os.path.join(performance_dir, filename))
