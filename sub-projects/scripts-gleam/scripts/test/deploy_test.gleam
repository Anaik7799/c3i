import gleeunit/should
import sys_scripts/commands/deploy.{
  Apply, DeployPlan, K8s, MissingArgument, MissingSubcommand, MissingTarget,
  Nixos, Plan, Rollback, UnknownFlag, UnknownSubcommand, UnknownTarget,
}

// --- happy paths -----------------------------------------------------------

pub fn parse_plan_nixos_test() {
  deploy.parse(["plan", "nixos", "nas1"])
  |> should.equal(
    Ok(DeployPlan(target: Nixos("nas1"), phase: Plan, dry_run: True)),
  )
}

pub fn parse_apply_k8s_default_dry_run_test() {
  deploy.parse(["apply", "k8s", "prod"])
  |> should.equal(
    Ok(DeployPlan(target: K8s("prod"), phase: Apply, dry_run: True)),
  )
}

pub fn parse_apply_k8s_execute_test() {
  deploy.parse(["apply", "k8s", "prod", "--execute"])
  |> should.equal(
    Ok(DeployPlan(target: K8s("prod"), phase: Apply, dry_run: False)),
  )
}

pub fn parse_execute_then_dry_run_flags_are_last_write_wins_test() {
  deploy.parse(["apply", "k8s", "prod", "--execute", "--dry-run"])
  |> should.equal(
    Ok(DeployPlan(target: K8s("prod"), phase: Apply, dry_run: True)),
  )
}

pub fn parse_rollback_nixos_test() {
  deploy.parse(["rollback", "nixos", "nas1", "--execute"])
  |> should.equal(
    Ok(DeployPlan(target: Nixos("nas1"), phase: Rollback, dry_run: False)),
  )
}

// --- error paths -----------------------------------------------------------

pub fn parse_empty_is_missing_subcommand_test() {
  deploy.parse([]) |> should.equal(Error(MissingSubcommand))
}

pub fn parse_unknown_subcommand_test() {
  deploy.parse(["yolo"])
  |> should.equal(Error(UnknownSubcommand("yolo")))
}

pub fn parse_missing_target_test() {
  deploy.parse(["plan"]) |> should.equal(Error(MissingTarget("deploy")))
}

pub fn parse_unknown_target_test() {
  deploy.parse(["plan", "hcloud", "server-1"])
  |> should.equal(Error(UnknownTarget("hcloud")))
}

pub fn parse_nixos_missing_host_test() {
  deploy.parse(["plan", "nixos"])
  |> should.equal(Error(MissingArgument("nixos", "<host>")))
}

pub fn parse_k8s_missing_namespace_test() {
  deploy.parse(["plan", "k8s"])
  |> should.equal(Error(MissingArgument("k8s", "<namespace>")))
}

pub fn parse_unknown_flag_test() {
  deploy.parse(["plan", "nixos", "nas1", "--wat"])
  |> should.equal(Error(UnknownFlag("--wat")))
}

// --- render helpers --------------------------------------------------------

pub fn describe_nixos_plan_test() {
  deploy.describe(DeployPlan(target: Nixos("web"), phase: Plan, dry_run: True))
  |> should.equal("plan nixos:web")
}

pub fn describe_k8s_apply_test() {
  deploy.describe(DeployPlan(target: K8s("dev"), phase: Apply, dry_run: False))
  |> should.equal("apply k8s:dev")
}
