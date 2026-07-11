# Quality Gates

Before merging to main, verify:

## Required

- [ ] Shell scripts lint clean (ShellCheck)
- [ ] Markdown files lint clean (markdownlint)
- [ ] Documentation updated for any behavior changes
- [ ] No secrets committed (check for hardcoded tokens/keys)
- [ ] `./setup` still works on a vanilla system (if bootstrap changed)

## CI Enforcement

| Gate            | Enforced By                      | Details             |
| --------------- | -------------------------------- | ------------------- |
| Shell scripts   | reviewdog/action-shellcheck      | All `*.sh` files    |
| Markdown        | reviewdog/action-markdownlint    | All `*.md` files    |

## Manual checks (not automated)

- Documentation updated
- No secrets committed
- Private files not accidentally tracked
- setup script remains portable
