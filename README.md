# Mote

Mote is a background macOS app for rewriting selected text anywhere.

## Layout

- `Sources/Mote`: agent app
- `Sources/MoteCore`: configuration, prompt, model, accessibility, replacement

## Commands

```bash
make build
make run
make test
```

## Config

Mote reads configuration from:

- `~/.config/mote/config.json`
- `~/.config/mote/commands/*.md`

Commands are user-authored files under `commands/`. Template files prefixed with `_` are ignored.
