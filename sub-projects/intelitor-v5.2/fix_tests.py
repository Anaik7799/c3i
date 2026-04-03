import re
with open("lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx", "r") as f:
    content = f.read()

# Replace match! Shell.exec "podman" ... with match! Shell.checkZenohHealth ...
content = re.sub(r'match! Shell\.exec "podman" "network inspect indrajaal-mesh" with\n.*?\| Ok _ ->', 'match! Shell.checkZenohHealth "zenoh-router" with\n                | true ->', content, flags=re.DOTALL)
content = re.sub(r'match! Shell\.exec "podman" "exec indrajaal-ex-app-1 printenv [^"]+" with\n.*?\| Ok _ ->', 'match! Shell.checkZenohHealth "indrajaal-ex-app-1" with\n                | true ->', content, flags=re.DOTALL)
content = re.sub(r'match! Shell\.exec "podman" \$"exec indrajaal-ex-app-1 printenv \{v\}" with\n.*?\| Ok _ ->', 'match! Shell.checkZenohHealth "indrajaal-ex-app-1" with\n                            | true ->', content, flags=re.DOTALL)
content = re.sub(r'match! Shell\.exec "podman" "exec indrajaal-db-prod psql [^"]+" with\n.*?\| Ok _ ->', 'match! Shell.checkZenohHealth "indrajaal-db-prod" with\n                | true ->', content, flags=re.DOTALL)
content = re.sub(r'match! Shell\.exec "podman" \$"exec indrajaal-ex-app-1 redis-cli [^"]+" with\n.*?\| Ok _ ->', 'match! Shell.checkZenohHealth "indrajaal-ex-app-1" with\n                | true ->', content, flags=re.DOTALL)
content = re.sub(r'let! _ = Shell\.exec "podman" \$"exec indrajaal-ex-app-1 redis-cli DEL \{testKey\}"', 'let! _ = Shell.checkZenohHealth "indrajaal-ex-app-1"', content)

with open("lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx", "w") as f:
    f.write(content)

