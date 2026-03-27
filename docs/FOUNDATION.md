# Foundation

## Product Name

Mote

The name should stay short and neutral. It suggests a small visible point rather than a large application surface. That matches the product: present only when needed, invisible the rest of the time.

## Product Statement

Mote is a background macOS app that rewrites selected text anywhere.

It is not a chat app, not a writing workspace, not a menu bar dashboard, and not an input method. It is a focused system layer that appears only when the user already has text selected and wants to transform it.

## Core User Problem

Users repeatedly perform the same rewrite actions across many apps:

- translate selected text
- rewrite in a known style
- shorten text without losing meaning
- apply a one-off edit instruction

Browser-specific tools solve part of this problem. The missing product is a macOS-native version that works across normal editable fields in most apps and keeps the interaction minimal.

## Target User

A keyboard-heavy macOS user who writes in many apps and wants text transformation to feel like a native editing action, not a separate workflow.

## Product Principles

1. Stay invisible by default.
2. Prefer selection-driven interaction over app-centric interaction.
3. Keep the UI smaller than the text task.
4. Make keyboard flow first-class, not fallback.
5. Degrade gracefully instead of pretending to support impossible targets.
6. Optimize for repeat use, not first-run demo appeal.
7. Keep settings out of the main UI.

## Product Shape

Mote runs as a background `LSUIElement` agent app.

It does not require:

- a Dock icon
- a menu bar item
- a persistent main window
- a conversation history UI
- a settings-heavy interface

Configuration lives under `~/.config/mote/`. Operational setup is handled by a minimal CLI named `motectl`.

## MVP Scope

The MVP must do the following:

- detect selected text in standard editable controls in common macOS apps
- show a tiny bubble near the selection when possible
- allow direct keyboard invocation without touching the mouse
- open a compact composer panel with pinned presets and freeform instruction input
- support slash-based preset selection inside the composer
- call a local or remote OpenAI-compatible model endpoint
- default to LM Studio configuration
- show the rewrite result and allow in-place replacement
- replace text directly when possible and fall back to paste-based replacement when needed
- keep secure fields and blacklisted apps excluded

## Non-Goals For MVP

The MVP must not include the following:

- chat history
- prompt marketplace
- multi-turn conversation UI
- menu bar application surface
- cloud account system
- analytics dashboard
- OCR or image understanding
- document diff viewer beyond basic result confirmation
- input method implementation
- local embedding or RAG system
- multi-provider abstraction beyond practical OpenAI-compatible support

## Constraints

### Platform

- macOS only
- native implementation
- Swift + AppKit-first approach
- SPM project layout

### Permissions

The product relies on macOS accessibility capabilities. Without Accessibility permission, the core feature does not exist.

Input Monitoring may also be required for some global keyboard event handling depending on the final hotkey implementation.

### Compatibility Reality

Mote cannot support every text surface in existence. It should target the practical majority of editable text fields exposed through standard Accessibility APIs.

Expected strong targets:

- AppKit text fields and text views
- WebKit-backed editable fields
- Chromium and Electron editable fields where Accessibility data is exposed correctly

Expected weak or unsupported targets:

- password fields
- canvas-based editors
- custom game UIs
- remote desktops and virtual machines
- apps with broken or intentionally limited Accessibility exposure

## Success Definition

The MVP is successful if a user can repeatedly do this in common apps:

1. Select text.
2. Trigger Mote with either bubble or keyboard shortcut.
3. Choose a preset or type a short instruction.
4. Receive a result quickly.
5. Replace the original text in place.
6. Return to writing with almost no context switch.

## Failure Conditions

Mote fails as a product if any of the following become true:

- it behaves like a separate AI workspace instead of a text action
- keyboard selection is not treated as first-class input
- bubble positioning is over-engineered while replacement remains unreliable
- settings and product chrome outweigh the rewrite action itself
- the app claims universal support but frequently fails to update text in place
