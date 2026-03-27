# Acceptance Criteria

## Definition Of Real MVP

Mote is not real until the following loop works in normal daily usage:

1. user selects text
2. Mote becomes available
3. user triggers rewrite by bubble or shortcut
4. user chooses preset or types instruction
5. local model returns rewritten text
6. user updates the original text in place

## Required Functional Criteria

### Selection Detection

- detects non-empty selection in standard editable fields
- works for mouse selection
- works for keyboard selection
- works for `Command + A`
- ignores secure fields
- respects app blacklist

### Bubble

- appears only for valid selection contexts
- does not steal focus
- disappears when selection is cleared or invalidated
- does not appear when placement is unreliable enough to be misleading

### Shortcut

- opens composer directly when a valid selection exists
- remains functional even when the bubble is suppressed
- supports keyboard-first usage end to end

### Composer

- opens quickly
- supports pinned presets
- supports slash preset selection
- accepts direct custom instruction
- submits with keyboard
- closes cleanly with escape

### Model Call

- uses configured OpenAI-compatible endpoint
- defaults to LM Studio settings
- handles timeout and connection failure visibly
- parses response into a usable rewrite result

### Replacement

- directly replaces selected text when Accessibility allows it
- falls back to paste-based replacement when safe
- preserves clipboard state safely when using paste strategy
- leaves the user in the original app after success
- never claims success when replacement failed

## Required Quality Criteria

### Speed

Target ranges for MVP:

- selection to bubble availability: under `150ms` after stabilization
- shortcut to composer visible: under `100ms`
- normal local rewrite turnaround: roughly `1s` to `3s` depending on local model
- update application step: under `100ms` after confirmation when target app allows it

### Reliability

Mote should be strong enough in the first target app set that the developer can genuinely use it every day.

Required first target app set:

- TextEdit
- Notes
- Safari
- Chrome

### Honesty

The app must degrade explicitly instead of pretending all targets work equally well.

Examples:

- no bubble if placement is unreliable
- fallback review if write-back is unavailable
- no action at all for secure fields

## Required Delivery Artifacts

Before calling the MVP ready, the repo should contain:

- working app target
- working `motectl` setup path
- config and preset defaults
- replacement logic with fallback
- tests for config, prompt building, and model client request construction
- docs that describe runtime behavior and supported failure modes

## Manual Verification Checklist

### Setup

- run `motectl init`
- verify config files exist under `~/.config/mote/`
- confirm LM Studio endpoint is reachable
- confirm Accessibility permission is granted

### Selection

- select text with mouse in TextEdit and verify Mote arms
- select text with `Shift + Arrow` and verify Mote arms
- select all with `Command + A` and verify Mote arms

### Trigger

- open composer from bubble
- open composer from shortcut without touching mouse

### Rewrite

- use `Translate`
- use `GitHub`
- use `Shorten`
- type a custom instruction

### Apply

- confirm in-place replacement works in TextEdit
- confirm in-place replacement works in Safari or Chrome textarea
- confirm clipboard is restored correctly after paste fallback

### Safety

- confirm no visible action occurs in secure fields
- confirm blacklisted app targets are ignored

## Release Gate

The MVP should not be considered ready to announce or dogfood until the daily loop is genuinely faster than copying text into a separate chat interface.
