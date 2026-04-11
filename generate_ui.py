import os

base_dir = "lib/cepaf_gleam/src/cepaf_gleam/ui"
os.makedirs(f"{base_dir}/lustre", exist_ok=True)
os.makedirs(f"{base_dir}/wisp", exist_ok=True)
os.makedirs(f"{base_dir}/tui", exist_ok=True)

features = [
    ("inference", "Inference"),
    ("pipeline_trace", "PipelineTrace"),
    ("chat_history", "ChatHistory"),
    ("voice", "Voice"),
    ("fmea", "FMEA"),
    ("ruliology", "Ruliology")
]

for name, title in features:
    # Lustre
    with open(f"{base_dir}/lustre/{name}.gleam", "w") as f:
        f.write(f"// {title} Lustre View\npub fn view() {{\n  \"{title} View\"\n}}\n")
    # Wisp
    with open(f"{base_dir}/wisp/{name}_api.gleam", "w") as f:
        f.write(f"// {title} Wisp API\npub fn handle_req() {{\n  \"{title} API\"\n}}\n")
    # TUI
    with open(f"{base_dir}/tui/{name}_view.gleam", "w") as f:
        f.write(f"// {title} TUI View\npub fn render() {{\n  \"{title} TUI\"\n}}\n")

print("Generated UI boilerplates successfully.")
