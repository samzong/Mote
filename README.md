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

Commands are user-authored Markdown files under `commands/`. Each file defines a rewrite instruction that can be invoked via `/filename` in the composer input.

### Built-in Commands

| Command | Description |
|---------|-------------|
| `/translate` | Translate the text to English |
| `/fix` | Fix grammar, spelling, and punctuation errors |
| `/polish` | Improve clarity and readability |
| `/shorten` | Make the text more concise |
| `/expand` | Elaborate and add more detail |
| `/formal` | Rewrite in a formal, professional tone |
| `/casual` | Rewrite in a casual, conversational tone |

### Custom Commands

Create a `.md` file in `~/.config/mote/commands/`:

```
# ~/.config/mote/commands/pirate.md
Rewrite the text in the style of a pirate.
```

Then use `/pirate` in the composer. You can also append extra context: `/translate to Japanese`.

Files prefixed with `_` are ignored.
