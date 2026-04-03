# ACE: Certified Container Checklist (CCC)

**Version**: 1.0.0
**Framework**: ACE v2.3.0 (Enterprise-Resilient)
**Objective**: 100% Deterministic Construction & Launch

---

## 1.0 Level 1: Construction Verification (Build-Time)
### 1.1 Source Integrity
- [ ] Host `mix.lock` matches current dependency graph.
- [ ] Nix derivation `containers/sopv51-elixir-app.nix` uses pinned `nixpkgs` revision.
- [ ] Native headers (`openssl.dev`, `zlib.dev`, `ncurses.dev`) included in package list.

### 1.2 Image Reification
- [ ] `nix-build` completes without interrupted