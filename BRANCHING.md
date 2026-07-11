# Branching Strategy

## Policy

- **main** is protected — never commit, push, merge, or rebase directly
- **Feature branches** for all changes
- **Merge commits** (not rebase) when integrating to main

## Branch Naming

```text
feat/<description>      — New features
fix/<description>       — Bug fixes
chore/<description>     — Maintenance, tooling
docs/<description>      — Documentation changes
refactor/<description>  — Code reorganization
```

## Pre-change verification

Before switching branches:

1. `git status` — confirm no uncommitted work
2. `git branch` — confirm current branch

## Forbidden Operations

- `git push --force` / `--force-with-lease`
- `git rebase` onto main/master
- `git reset --hard` on main/master
- `git reflog expire`, `git filter-branch`, `git filter-repo`
- `git commit` or `git push` directly to main/master

## Safe operations (no prompt needed)

- `git status`, `git diff`, `git log --oneline`, `git show`, `git branch -a`
- `chezmoi apply`, `chezmoi update`, `chezmoi status`
- `mise exec`, `ls`, `cat`, `grep`, `find`, `pwd`

## Ask before doing

- `git add`, `git commit`, `git push` (non-force)
- `git checkout`, `git switch`, `git merge`, `git rebase`
- `terraform apply`, `kubectl delete`, `docker system prune`
- Editing `.env`, `kubeconfig`, `terraform.tfstate`

## Why these rules exist

- Prevent accidental pushes to protected branches
- Avoid destructive operations
- Protect secrets, state files, and config
- Ensure proper review workflow
