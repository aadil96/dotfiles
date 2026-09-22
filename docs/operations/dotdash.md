# dotdash — local dotfiles dashboard

Linux-only user service that serves the dashboard on `127.0.0.1:7842`.

## Unit

- Template: `dot_config/systemd/user/dotdash.service.tmpl` (renders only on Linux via `{{ .chezmoi.os }}` guard; empty on macOS/other)
- Exec: `%h/.local/bin/mise exec -- node <data-home>/dotdash/app/server.js`, with `<data-home>` rendered from `XDG_DATA_HOME` (default: `$HOME/.local/share`).
- Env: `HOSTNAME=127.0.0.1`, `PORT=7842`, `NODE_ENV=production`
- Restart: `on-failure` with `RestartSec=3`
- Install: `WantedBy=default.target`

## Build and install (dashboard repo)

From `dotfiles-dashboard`:

```sh
./scripts/install-standalone.sh   # pnpm build + atomic install to $XDG_DATA_HOME/dotdash/app
```

No automatic service enablement. The installer does not enable lingering.
Use the same `XDG_DATA_HOME` when installing and applying the unit. After changing it, reinstall, reapply, reload systemd, and restart the service.

## Apply and enable

```sh
chezmoi apply --no-tty --refresh-externals=never ~/.config/systemd/user/dotdash.service
systemctl --user daemon-reload
systemctl --user enable --now dotdash
systemctl --user status dotdash
curl -s http://127.0.0.1:7842/api/health
```

## Verify

```sh
python3 docs/tests/test_dotdash_service.py
chezmoi execute-template --file dot_config/systemd/user/dotdash.service.tmpl
systemd-analyze verify ~/.config/systemd/user/dotdash.service
systemctl --user is-active dotdash
ss -tlnp | grep 7842   # must show 127.0.0.1:7842 only
```

## Stop / rollback

```sh
systemctl --user disable --now dotdash
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/dotdash/app"
# optional: systemctl --user daemon-reload
```

## Notes

- macOS/non-Linux: template renders empty; no service is installed.
- Apply the service target explicitly; a global `chezmoi apply` may execute unrelated pending scripts.
- Dashboard owns the standalone build and installer; dotfiles owns the service template and this documentation.
- Never expose beyond loopback; mutations require one-shot tokens, loopback Host, and same-origin Origin.
