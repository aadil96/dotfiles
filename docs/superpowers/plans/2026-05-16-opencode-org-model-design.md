# OpenCode Organization Operating Model — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create 7 global OpenCode organization agents (CEO, CTO, PM, Finance, Security, QA, DevOps) and 6 reusable governance skills under chezmoi-managed `~/.config/opencode/`, without modifying existing config.

**Architecture:** Thin role-identity agent files delegate decision-making to skills. Skills provide reusable reasoning frameworks. Build orchestrator selects org agents via org-routing skill. No cross-org delegation — org agents call execution agents only.

**Tech Stack:** chezmoi dotfiles, OpenCode agent files, SKILL.md markdown, YAML frontmatter

---

## Context & Decisions

| Decision | Rationale |
| -------- | --------- |
| EM excluded from v1 | Deferred to Phase 3 based on observed need |
| CEO strategic-only | Only consulted for strategic events, not normal feature flow |
| Build wiring deferred | `.opencode/opencode.jsonc` not modified in Phase 1 |
| org-governance shared skill | Reduces prompt duplication across org agents |
| Agents stripped to role identity | Detailed process moved to skills; agents are thin dispatchers |
| No project-local changes | project.md, stack.md, workflows/ deferred to later phases |

## Phase 1: Skills (6 files)

**6 new skills under `dot_config/opencode/skills/`**

- [x] **1.1:** Create `dot_config/opencode/skills/org-routing/SKILL.md` — When to consult each org role
- [x] **1.2:** Create `dot_config/opencode/skills/org-governance/SKILL.md` — Shared rules for all org agents
- [x] **1.3:** Create `dot_config/opencode/skills/decision-framework/SKILL.md` — First-principles trade-off analysis
- [x] **1.4:** Create `dot_config/opencode/skills/architecture-principles/SKILL.md` — SOLID-style + tech selection criteria
- [x] **1.5:** Create `dot_config/opencode/skills/security-policies/SKILL.md` — STRIDE threat modeling + checklists
- [x] **1.6:** Create `dot_config/opencode/skills/cost-optimization/SKILL.md` — Cost analysis + build-vs-buy framework

## Phase 2: Agents (7 files)

**7 new agents under `dot_config/opencode/agents/`**

- [x] **2.1:** Create `dot_config/opencode/agents/ceo.md` — Strategic executive
- [x] **2.2:** Create `dot_config/opencode/agents/cto.md` — Architecture and tech stack
- [x] **2.3:** Create `dot_config/opencode/agents/pm.md` — Requirements and acceptance criteria
- [x] **2.4:** Create `dot_config/opencode/agents/finance.md` — Cost analysis and licensing
- [x] **2.5:** Create `dot_config/opencode/agents/security.md` — Threat modeling and compliance
- [x] **2.6:** Create `dot_config/opencode/agents/qa.md` — Test strategy and quality gates
- [x] **2.7:** Create `dot_config/opencode/agents/devops.md` — Deployment and observability

## Phase 3: Verification

- [x] **3.1:** List all new files — 7 agents + 6 skills confirmed present
- [x] **3.2:** Run `chezmoi apply --force` — success, no errors
- [x] **3.3:** Verify target files — 7 agents + 6 skill dirs at `~/.config/opencode/`
- [x] **3.4:** Run `chezmoi status` — only timestamp drift in chezmoi-expert template (harmless)
- [x] **3.5:** Code review — all 13 files passed review (spec-compliant, frontmatter valid, permissions consistent)

## Notes

- All paths relative to `/home/aadil/.local/share/chezmoi/` (chezmoi source directory)
- After `chezmoi apply`, files land in `~/.config/opencode/...`
- Skills auto-discovered from `~/.config/opencode/skills/` — no config registration needed
- Existing config (agent/, profiles/, plugin/, oh-my-openagent.json) not touched
- Exact file contents defined in spec: `docs/superpowers/specs/2026-05-16-opencode-org-model-design.md`
