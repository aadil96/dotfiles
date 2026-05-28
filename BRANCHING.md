# Branching Strategy

## Policy

- **main** is protected — never commit, push, merge, or rebase directly
- **Feature branches** for all changes
- **Merge commits** (not rebase) when integrating to main

## Branch Naming

```
feat/<description>      — New features
fix/<description>       — Bug fixes
chore/<description>     — Maintenance, tooling
docs/<description>      — Documentation changes
refactor/<description>  — Code reorganization
```

## Forbidden Operations

- Force push to any branch
- Rebase onto protected branches
- Direct commits to main
- Destructive git operations (reset --hard, filter-branch)
