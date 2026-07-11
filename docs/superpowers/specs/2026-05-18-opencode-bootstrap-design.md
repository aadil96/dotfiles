# Phase 5: Operational Maturity — Project Bootstrap System

**Date:** 2026-05-18
**Status:** Draft

## Overview

Transform the organization operating model (Phase 4) into a reusable platform that can bootstrap new repositories automatically. The bootstrap system provides project archetypes with sensible defaults, recommended workflows, recommended skills, and recommended organization participants — all accessible via `opencode init`.

### Philosophy

- **Separation of concerns:** OpenCode command owns interaction; shell script owns generation. No generation logic in prompts or agents.
- **Declarative archetypes:** `archetype.yaml` is data-only — no commands, logic, or prompts.
- **Inheritance over duplication:** Archetypes extend parent archetypes. Base `common` provides shared defaults. Child overrides parent for file templates; arrays are union + deduplicate; objects are deep-merged.
- **Composition over sub-archetypes:** Components (auth, payments, observability) augment rather than multiply archetypes. Components apply last in the resolution chain and cannot override archetype identity.
- **Portability:** The shell script runs independently of OpenCode runtime.
- **Stable = templated via chezmoi:** Only stable, reusable components are managed through chezmoi. Experimental behavior is not.

### Design Constraints

- Preserve global vs project separation
- Avoid duplicating organization logic
- Keep bootstrap lightweight
- Script API boundary: prompt owns interaction, script owns filesystem/template knowledge

## Architecture

### Ownership Boundaries

| Layer | Owns | Location |
| ---------------------- | -------------------------------------------------------- | --------------------------------------------- |
| User | Intent, parameter input | — |
| OpenCode command | Interaction, display, calling script API | `opencode.json` command registration |
| Shell script | Generation logic, template resolution, validation, discovery | `~/.config/opencode/tools/opencode-init` |
| Templates (chezmoi) | Archetype definitions, workflow assets, components | `~/.config/opencode/templates/` |
| Global skills (chezmoi) | Skill definitions (reused, not copied) | `~/.config/opencode/skills/` |
| Generated project | Project-specific config | `.opencode/**` in target directory |

### Init Flow

```text
opencode init
    ↓
OpenCode command prompt (interaction only)
    │  opencode-init --list-archetypes
    │  user selects archetype
    │  opencode-init --list-components <archetype>
    │  user selects components
    │  user provides project name/output dir
    │  opencode-init <archetype> --dry-run [--components ...] [--output ...]
    │  display preview to user
    │  user confirms
    ↓
opencode-init <archetype> [--components ...] [--output ...]
    ↓
1. Parse args, validate
2. Load + validate manifest.yaml
3. Load archetype.yaml for selected archetype
4. Validate: extends target exists, no circular inheritance, components exist, workflows exist
5. Resolve inheritance chain: common → parent → ... → selected archetype
6. Load selected components
7. Merge all yaml (deep merge objects, union arrays)
8. Resolve final asset lists: workflows (union + dedupe), skills (union + dedupe)
9. If --dry-run: print plan and exit
10. Copy file templates (child overrides parent)
11. Generate project.md using merged data
12. Generate stack.md using merged data
13. Copy selected workflows from templates/workflows/ to .opencode/workflows/
14. Write .opencode/.generated.yaml metadata
15. Print scaffold summary
```

### Script CLI API

```text
opencode-init --list-archetypes                    → human-readable list
opencode-init --list-archetypes --json             → JSON array
opencode-init --list-components <archetype>        → human-readable list
opencode-init --list-components <archetype> --json → JSON array
opencode-init <archetype> [options]

Options:
  --components <list>    Comma-separated component names
  --output <dir>         Target directory (default: cwd)
  --dry-run              Preview only, no files written
  --force                Overwrite existing files
  --merge                Merge with existing files
  --skip-existing        Skip files that already exist
  --json                 Machine-readable output (for --dry-run)

Exit codes:
  0 — success
  1 — validation error
  2 — file exists (without --force/--merge/--skip-existing)
```

## Archetype Model

### Inheritance Hierarchy

```text
common
├── library
│   └── cli-tool
├── backend-service
│   └── saas-platform
├── frontend-app
└── infrastructure
```

### Inheritance Meaning

| Archetype | Meaning |
| ---------------- | -------------------------------------------------------------------------------- |
| common | Base for all archetypes. Provides project.md, stack.md, feature + bug workflows. |
| library | Reusable package, minimal deployment concerns. |
| cli-tool | Library + executable interface. |
| backend-service | Deployable runtime, APIs, infrastructure, operational lifecycle. |
| saas-platform | backend-service + multi-tenancy, billing, auth, cost controls, incident workflows. |
| frontend-app | Standalone UI application. |
| infrastructure | Infrastructure/ platform code (Terraform, Kubernetes, CI/CD). |

### Inheritance Resolution Order

```text
common
    ↓
parent archetypes (root → leaf, if extends chain)
    ↓
selected archetype
    ↓
selected components (always last)
    ↓
final scaffold generation
```

### Merge Rules

| Type | Strategy |
| ----------------------------------------------- | ----------------------------------------------------- |
| Objects (yaml) | Deep merge — child values override parents |
| Arrays (org_participants, skills, workflows) | Union + deduplicate |
| File templates (project.md, stack.md) | Child overrides parent |
| Workflows | Union + deduplicate |
| Components | Append to scaffold (cannot override archetype identity) |

## archetype.yaml Schema

```yaml
# archetype.yaml — declarative only, no execution logic
schema_version: 1           # required: structure compatibility
migration_version: 1        # required: template migration version
name: <string>              # required: matches directory name
description: <string>       # required: one-line description
extends: <string>           # optional: parent archetype name

defaults:                   # optional: scaffold-time variables
  project:
    language: <string>      # mutable choice, not prescriptive
    runtime: <string>

required_workflows:         # always included
  - feature-development
  - bug-fix

optional_workflows:         # user may opt in
  - deployment
  - incident-response

required_skills:            # must exist → fail if missing
  - feature-lifecycle

recommended_skills:         # should exist → warn only if missing
  - architecture-principles
  - security-policies

org_participants:
  always:                   # always consulted
    - PM
    - CTO
  conditional:              # consulted when conditions met
    Security: "auth, secrets, external dependencies, or PII"
    DevOps: "deployment or infrastructure changes"

components:                 # composition options
  optional:
    - auth
    - observability
```

## Component Model

Components are first-class template citizens at `templates/components/<name>/`.

### component.yaml Schema

```yaml
schema_version: 1
name: <string>
description: <string>

adds:
  workflows:
    - security-review
  skills:
    - security-policies
  stack_sections:
    - authentication
  project_defaults:
    auth_provider: "none"
```

### Available Components

| Component | Adds Workflows | Adds Skills | Adds Stack Sections | Generates Code |
| ----------- | --------------- | ------------- | --------------------- | ---------------- |
| auth | security-review | security-policies (recommended) | Authentication | No |
| payments | — | — | Payments/Billing | No |
| observability | incident-response | — | Monitoring, Logging | No |
| queue | — | — | Message Queue | No |
| notifications | — | — | Notifications | No |

### Component Rules

- Components always apply last (after archetype inheritance)
- Components cannot override archetype identity
- Components augment only: workflows, skills, stack sections, project defaults
- Duplicate component detection fails early

### Component Constraints

Components are metadata-only in this phase. They define:

- Workflow additions (which workflow files to include)
- Skill recommendations (which skills to reference)
- Stack sections (which sections appear in stack.md)
- Project defaults (default variable values)

Components must NOT generate implementation code in this phase:

- No JWT or auth code
- No Terraform or infrastructure modules
- No application source code
- No framework-specific files

Implementation code generation is a future extension point.

## Template Structure

### File Tree (chezmoi-managed)

```text
dot_config/opencode/
├── opencode.json                            ← modified: add init command
├── templates/
│   ├── manifest.yaml                    ← template package metadata
│   ├── archetypes/
│   │   ├── common/archetype.yaml
│   │   ├── library/archetype.yaml
│   │   ├── cli-tool/archetype.yaml
│   │   ├── backend-service/archetype.yaml
│   │   ├── saas-platform/archetype.yaml
│   │   ├── frontend-app/archetype.yaml
│   │   └── infrastructure/archetype.yaml
│   ├── workflows/                       ← generation assets only
│   │   ├── feature-development.md
│   │   ├── bug-fix.md
│   │   ├── deployment.md
│   │   ├── architecture-review.md
│   │   ├── incident-response.md
│   │   └── security-review.md
│   ├── components/
│   │   ├── auth/
│   │   │   ├── component.yaml
│   │   │   └── stack.md.tmpl
│   │   ├── payments/
│   │   │   ├── component.yaml
│   │   │   └── stack.md.tmpl
│   │   ├── observability/
│   │   │   ├── component.yaml
│   │   │   └── stack.md.tmpl
│   │   ├── queue/
│   │   │   ├── component.yaml
│   │   │   └── stack.md.tmpl
│   │   └── notifications/
│   │       ├── component.yaml
│   │       └── stack.md.tmpl
│   ├── project.md.tmpl
│   └── stack.md.tmpl
└── tools/
    └── opencode-init
```

### templates/manifest.yaml

```yaml
schema_version: 1
migration_version: 1
template_version: 1
generator_min_version: 1
```

### Generated Project Tree

```text
<project>/
├── .opencode/
│   ├── project.md
│   ├── stack.md
│   ├── workflows/
│   │   ├── feature-development.md
│   │   ├── bug-fix.md
│   │   └── ...
│   ├── .generated.yaml
│   └── README.md
```

No `opencode.json` is generated by default. Only generated if project-specific overrides, agents, or commands exist.

### .opencode/.generated.yaml

```yaml
schema_version: 1
migration_version: 1
generator_version: 1
template_version: 1
template_manifest_hash: "<sha256 of templates/manifest.yaml>"
archetype: saas-platform
inheritance_chain:
  - common
  - backend-service
  - saas-platform
components:
  - auth
  - observability
generated_at: "2026-05-18T12:00:00Z"
```

The `template_manifest_hash` enables future `opencode upgrade` to detect template drift and offer migration.

## Validation

### Validation Order

1. CLI argument parsing
2. Load manifest.yaml — validate schema_version is supported
3. Load archetype.yaml — validate schema_version, name, extends target exists
4. Resolve inheritance chain — detect circular inheritance
5. Load each component — validate component exists
6. Merge all data
7. Validate every referenced workflow exists in templates/workflows/
8. Validate required_skills exist in ~/.config/opencode/skills/ → fail if missing
9. Validate recommended_skills exist in ~/.config/opencode/skills/ → warn if missing
10. Validate target directory: warn if exists, fail if --force not set and files would be overwritten

### Validation Errors

| Error | Message | Exit Code |
| ------------------- | ------------------------------------------------------------------ | --------- |
| Archetype not found | `Archetype '<name>' not found` | 1 |
| Circular inheritance | `Circular inheritance detected: a → b → c → a` | 1 |
| Component not found | `Component '<name>' not found` | 1 |
| Workflow not found | `Workflow '<name>' not found in templates/workflows/` | 1 |
| Schema unsupported | `Schema version <v> not supported (max: <max>)` | 1 |
| File exists | `File '<path>' already exists (use --force, --merge, or --skip-existing)` | 2 |

## Idempotency

Running `opencode init` twice should not silently overwrite.

| Flag | Behavior |
| ---------------- | ----------------------------------------------------------------------------------- |
| (none) | Fail with exit code 2 if any generated file exists |
| `--force` | Overwrite all existing files |
| `--merge` | Smart merge: skip identical files, update generated sections, preserve user-modified sections, show diff + require confirmation on conflicts |
| `--skip-existing` | Skip files that already exist, create only new ones |

## Chezmoi Management

### Managed by chezmoi (stable)

- All `templates/` contents (archetype.yaml files, workflows, components, shared templates, manifest.yaml)
- `tools/opencode-init` script
- `opencode.json` (with `init` command registration)

### NOT managed by chezmoi (generated or experimental)

- Generated `.opencode/` directories in user projects
- `.opencode/.generated.yaml` (per-project, never templated)
- Experimental archetypes under development
- Local project-specific `opencode.json` overrides

### Why This Boundary

- Generation logic is stable and reusable → chezmoi tracks it
- Generated output is project-specific → git tracks it in the project repo
- Experimental archetypes are in flux → not templated until stable

## future Repo Lifecycle Example

### 1. Bootstrap

```bash
# User creates a new SaaS project
opencode init

# OpenCode command:
#   opencode-init --list-archetypes
#   user selects: saas-platform
#   opencode-init --list-components saas-platform
#   user selects: auth, observability
#   opencode-init saas-platform --components auth,observability --dry-run
#   user confirms → generate

# Result:
my-saas/
├── .opencode/
│   ├── project.md              # filled from template + archetype defaults
│   ├── stack.md                # filled from template + component additions
│   ├── workflows/
│   │   ├── feature-development.md
│   │   ├── bug-fix.md
│   │   ├── deployment.md
│   │   ├── architecture-review.md
│   │   └── incident-response.md
│   └── .generated.yaml         # template lock metadata
```

### 2. Development

Organization agents, workflows, and skills are available immediately. The build orchestrator routes work through the org model.

### 3. Template Upgrade

```bash
# Months later, templates are updated
chezmoi update → pulls new templates/ and opencode-init

# User runs upgrade detection
opencode upgrade --check   # compares manifest hashes
opencode upgrade --diff    # shows what changed
opencode upgrade --apply   # merges template changes into project
```

### 4. Archetype Migration

```bash
# Project needs to change archetype
opencode init --migrate frontend-app --output .
# Re-scaffolds project.md, stack.md, workflows for new archetype
# Preserves existing .opencode/.generated.yaml for audit trail
```

## Key Decisions

| Decision | Choice | Rationale |
| --------------- | --------------------------------------------- | --------------------------------------------------------------- |
| Script location | `~/.config/opencode/tools/opencode-init` | `bin/` implies global PATH utility; this is an internal org tool |
| Skill references | Reuse global `~/.config/opencode/skills/` | No template copies = single source of truth, no drift |
| Inheritance model | Capability extension | backend-service extends common, not library — different concerns |
| Component model | Composition (not sub-archetypes) | Avoids archetype explosion (saas-platform-with-payments, etc.) |
| Output format | JSON flag for machine-readable | Enables future TUI, web UI, IDE, automation integrations |
| Idempotency | Fail-safe with --force/--merge/--skip-existing | Prevents accidental overwrites |
| Template lock | SHA256 hash in .generated.yaml | Enables future upgrade/migration tooling |

## Scope — This Phase

### Implement Now

- `opencode init` command
- 6 archetypes (with inheritance + composition)
- 5 components (auth, payments, observability, queue, notifications)
- Scaffold generation (project.md, stack.md, workflows, .generated.yaml)
- opencode-init script with all features (--list-archetypes, --list-components, --dry-run, --json, --force, --merge, --skip-existing)
- Validation (schema, circular inheritance, component/workflow/skill existence, duplicate detection, target directory)
- Idempotency (--force/--merge/--skip-existing with merge diff confirmation)

### Deferred (future extension points)

- `opencode upgrade` command
- Template drift detection (manifest hash comparison)
- Migration tooling (archetype migration, version upgrades)
- Template diff engine
- Component code generation (components are metadata-only in this phase)
