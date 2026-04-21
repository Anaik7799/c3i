//// scripts/common/registry_index — canonical list of all script manifests.
////
//// Single point of truth for tools that need to enumerate runnable scripts
//// (`scripts/tools/list`, `scripts/tools/retain`, `scripts/tools/metrics_dump`).
//// Breaking this list out avoids the import cycle between those tools.

import scripts/common/manifest as mfst
import scripts/probe/public_interface
import scripts/registry/saplan_smoke
import scripts/tools/build_nif
import scripts/tools/build_nif_cross
import scripts/tools/guard_no_shell
import scripts/tools/metrics_dump
import scripts/tools/scaffold
import scripts/pi/operator_view
import scripts/drift/br_mrg_drift_p0_checklist
import scripts/verify/feature_evolution
import scripts/verify/formal_check
import scripts/verify/metrics_roundtrip
import scripts/verify/symbiosis_smoke
import scripts/verify/ultrathink_symbiosis_pass

/// Whenever a new runnable script is added, append its `manifest()` here and
/// add the import above.
pub fn all() -> List(mfst.Manifest) {
  [
    public_interface.manifest(),
    saplan_smoke.manifest(),
    symbiosis_smoke.manifest(),
    metrics_roundtrip.manifest(),
    feature_evolution.manifest(),
    build_nif.manifest(),
    build_nif_cross.manifest(),
    guard_no_shell.manifest(),
    metrics_dump.manifest(),
    scaffold.manifest(),
    operator_view.manifest(),
    br_mrg_drift_p0_checklist.manifest(),
    formal_check.manifest(),
    ultrathink_symbiosis_pass.manifest(),
  ]
}
