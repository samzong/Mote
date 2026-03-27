# System Architecture

## Runtime Shape

Mote is composed of three runtime surfaces:

1. `Mote`
   A background macOS agent app with no Dock icon and no menu bar presence.
2. `MoteCore`
   Shared logic for configuration, prompts, model requests, Accessibility access, and replacement behavior.
3. `motectl`
   A minimal CLI for setup, diagnostics, and preset/config editing.

## Packaging And Project Layout

The project follows an SPM-first structure.

### Current Top-Level Layout

- `Package.swift`
- `Makefile`
- `Scripts/`
- `Sources/Mote/`
- `Sources/MoteCore/`
- `Sources/motectl/`
- `Tests/MoteCoreTests/`

### Planned Module Layout

#### `Sources/Mote`

App runtime and UI surface.

Recommended responsibilities:

- `App/`
  - process startup
  - permission bootstrapping
  - lifecycle wiring
- `Integration/`
  - selection watching
  - frontmost app observation
  - global hotkey monitoring
- `Overlay/`
  - bubble window
  - composer panel
  - result panel

#### `Sources/MoteCore`

Shared domain logic and platform integration helpers.

Recommended responsibilities:

- `Config/`
  - config schema
  - config loading and saving
  - preset collection loading
- `Models/`
  - selection context
  - rewrite request/result
  - preset models
- `Prompt/`
  - final prompt/message construction
- `LLM/`
  - OpenAI-compatible request and response types
  - network client
- `Accessibility/`
  - selected text reading
  - selection bounds resolution
  - direct replacement writer
- `Replacement/`
  - replacement orchestration
  - direct replace strategy
  - paste replace strategy
- `Utils/`
  - clipboard transaction safety
  - logging

#### `Sources/motectl`

Minimal command-line control surface.

Required commands for MVP:

- `motectl init`
- `motectl doctor`
- `motectl config`
- `motectl probe`

Optional but useful soon after:

- `motectl preset list`
- `motectl preset add`
- `motectl preset edit <id>`

## Application Mode

`Mote` must run with `LSUIElement = true`.

Implications:

- no Dock icon
- no normal app chrome
- windows are utility surfaces only
- the app behaves like a background system tool rather than a foreground workspace

## Core Event Pipeline

### Step 1: Observe Context

The app watches:

- frontmost application
- focused Accessibility element
- selection range changes
- selected text changes
- mouse-up and keyboard events that likely finalize selection changes

### Step 2: Resolve Selection

For the current focused element, attempt to read:

- selected text
- selected text range
- bounds for selected range
- writable capability of target element
- secure-field state

### Step 3: Decide Visibility

Given the resolved selection context:

- if invalid, hide everything
- if valid and placeable, show bubble after debounce
- if valid but not placeable, keep shortcut-only path available

### Step 4: Open Composer

When triggered by bubble or shortcut:

- capture the current selection context snapshot
- open the composer panel
- allow preset or instruction input

### Step 5: Build Model Request

Prompt assembly inputs:

- selected text
- chosen preset
- optional user instruction
- app context when relevant

### Step 6: Call Model Endpoint

Send an OpenAI-compatible request to the configured endpoint.

### Step 7: Review Result

Show compact result review with `Cancel` and `Update`.

### Step 8: Apply Replacement

Replacement order:

1. direct write through Accessibility when safe
2. paste-based replacement with clipboard preservation
3. explicit fallback when neither can be guaranteed

## Accessibility Layer

The Accessibility layer is the hard part of the product.

### Primary Reads

The implementation should center around:

- `AXUIElementCreateSystemWide()`
- `kAXFocusedUIElementAttribute`
- `kAXSelectedTextAttribute`
- `kAXSelectedTextRangeAttribute`
- `kAXBoundsForRangeParameterizedAttribute`
- `kAXValueAttribute`

### Required Output From Selection Read

A usable selection snapshot should include:

- bundle identifier of the frontmost app
- focused element reference
- selected text string
- selected text range
- best-effort screen bounds
- secure-field status
- direct-write capability

### Read Reliability Strategy

Do not rely on a single trigger source.

Use a mixed strategy:

- Accessibility notifications when available
- key event based refresh for keyboard selection flows
- mouse-up refresh for drag selection flows
- focused-element refresh for app changes

## Trigger Architecture

### Passive Trigger Sources

- `leftMouseUp`
- focused element changed
- selected text changed notification
- debounced re-check after keyboard selection gestures

### Active Trigger Sources

- configurable global shortcut
- optional experimental `Fn` trigger

`Fn` must not be the only supported shortcut path.

## Bubble Placement Strategy

### Placement Order

1. exact selection bounds from Accessibility
2. field-level bounds fallback
3. no bubble, shortcut-only

### Placement Rules

- never steal focus
- never cover the text aggressively
- prefer consistency over pixel-perfect attachment

## Composer Architecture

The composer should be implemented as a compact focusable panel.

Requirements:

- can become key window
- can accept keyboard input immediately
- can close cleanly and restore focus
- can switch between composing and result review states without spawning large UI surfaces

## Model Client

### Protocol

The MVP only needs practical compatibility with OpenAI-style chat completion endpoints.

### Default Target

LM Studio local server.

Default configuration:

- base URL: `http://127.0.0.1:1234/v1`
- request path: `/chat/completions`
- API key: placeholder value accepted by local servers
- model: user-configurable

### Request Shape

The request body should follow the OpenAI-compatible chat format.

Example shape:

```json
{
  "model": "qwen2.5-7b-instruct",
  "messages": [
    {"role": "system", "content": "You are a concise editor."},
    {"role": "user", "content": "Instruction:\nShorten the selected text\n\nSelected text:\n..."}
  ],
  "temperature": 0.2,
  "max_tokens": 1024,
  "stream": false
}
```

### Prompt Strategy

The final prompt should be built from:

- preset system prompt
- preset default instruction template
- user override instruction when supplied
- selected text

The system should prefer deterministic, concise prompt composition over rich prompt templating.

## Configuration

### Location

- `~/.config/mote/config.json`
- `~/.config/mote/commands/*.md`

`motectl init` creates `config.json` and `commands/_template.md`.
The `commands/` directory is user-authored and should not be populated with built-in commands.

### `config.json`

```json
{
  "base_url": "http://127.0.0.1:1234/v1",
  "api_key": "",
  "model": "qwen2.5-7b-instruct",
  "temperature": 0.2,
  "max_tokens": 1024,
  "hotkey": {
    "key": "space",
    "modifiers": ["option"]
  }
}
```

### `commands/*.md`

```md
---
name: Translate
description: Translate the selected text into concise natural Chinese.
order: 10
---

Translate the selected text into concise natural Chinese. Preserve structure, terminology, and formatting.
```

Commands are loaded from file names under `commands/`.

- `translate.md` becomes command id `translate`
- `name`, `description`, and `order` are read from frontmatter
- the markdown body becomes the default instruction
- commands are sorted by `order`
- only the first 5 commands should be shown by default
- markdown files prefixed with `_` are ignored and may be used as templates

## Replacement Engine

Replacement must be layered.

### Strategy A: Direct Accessibility Write

Use direct mutation when the field exposes writable value and the selected range can be reliably replaced.

Advantages:

- no clipboard interference
- cleaner state restoration
- more native behavior

### Strategy B: Paste-Based Replacement

When direct write fails:

1. snapshot clipboard state
2. write result to clipboard
3. synthesize paste action into the target app
4. restore clipboard if safe

Clipboard restoration must be transactional. Never assume the user did not change the clipboard during the operation.

### Strategy C: Explicit Fallback

If no safe write path exists:

- present the result
- allow copy
- do not falsely report success

## Security And Privacy

Required defaults:

- secure fields are excluded
- blacklisted apps are excluded
- logs do not persist selected content by default
- the app does not store rewrite history by default

## Why This Is Not An Input Method

An input method is the wrong abstraction for the MVP.

Reasons:

- the product is selection-based, not text-composition-based
- Accessibility gives a more direct path to selected text and replacement
- input method complexity is much higher for no MVP benefit
- the product should remain a rewrite action, not become keyboard infrastructure
