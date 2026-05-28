# Quality Gates

Before merging to main, verify ALL of the following:

## Required Gates

- [ ] Code compiles/lints without errors
- [ ] Tests pass
- [ ] Documentation is updated
- [ ] No secrets committed
- [ ] ADR created for architecture changes
- [ ] CHANGELOG updated (if applicable)

## CI Enforcement

The CI pipeline (`.github/workflows/ci.yml`) will automatically enforce:

| Gate            | Enforced By                    | Details                          |
|-----------------|--------------------------------|----------------------------------|
| Linting         | ShellCheck + markdownlint      | All shell scripts and markdown   |
| Tests           | Test suite runner              | `scripts/tests/run-all.sh`     |

Manual gates (not yet automated) must be checked by the developer:

- Documentation updated
- No secrets committed
- ADR created for architecture changes
- CHANGELOG updated
