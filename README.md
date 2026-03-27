# Mote

Mote is a background macOS app for rewriting selected text anywhere.

## Layout

- `Sources/Mote`: agent app
- `Sources/MoteCore`: configuration, prompt, model, accessibility, replacement
- `Sources/motectl`: small CLI/TUI-style configuration tool

## Commands

```bash
make build
make run
make test
make run-cli ARGS="init"
make run-cli ARGS="doctor"
```

## Config

Mote reads configuration from:

- `~/.config/mote/config.json`
- `~/.config/mote/commands/*.md`

`motectl init` creates `config.json` and `commands/_template.md`.
Commands are user-authored files under `commands/`. Template files prefixed with `_` are ignored.
