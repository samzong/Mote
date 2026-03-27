# Implementation Plan

## Development Goal

Ship an MVP that proves the complete loop:

- detect selected text
- surface an affordance or shortcut
- collect rewrite intent
- call a model
- replace the text in place

Do not overbuild before this loop is real.

## Recommended Execution Order

### Phase 0: Lock The Skeleton

Current state already exists:

- SPM package
- `Mote` app target
- `MoteCore` target
- `motectl` target
- base config schema

Tasks:

- keep target names stable
- keep config file locations stable
- keep `LSUIElement` app mode stable

### Phase 1: Configuration And Diagnostics

Implement `motectl` enough that engineers can bootstrap a working local setup without touching source.

Required tasks:

- `motectl init`
  - create config directory
  - write default config and preset files if missing
- `motectl doctor`
  - report config existence
  - report Accessibility permission status
  - report endpoint reachability
- `motectl probe`
  - send a minimal test request to configured model endpoint
  - print success or failure clearly

Exit condition:

- an engineer can point Mote at LM Studio and prove connectivity from the CLI

### Phase 2: Selection Read Path

This is the first truly critical product phase.

Required tasks:

- implement focused element resolution
- implement selected text read
- implement selected range read
- implement secure-field detection
- implement bounds resolution
- implement selection snapshot model

Required debug behavior:

- on selection refresh, log whether selection is valid, readable, writable, and placeable

Exit condition:

- standard editable fields in at least Safari, Chrome, Notes, and TextEdit produce correct selection snapshots

### Phase 3: Trigger System

Required tasks:

- mouse-up trigger
- keyboard selection refresh trigger
- active shortcut trigger
- frontmost app change handling
- debounce logic for selection stabilization

Special requirement:

- `Command + A` must result in a valid selection refresh path
- keyboard selection must be treated as first-class, not as a secondary patch

Exit condition:

- selection-driven state changes are stable for mouse and keyboard workflows

### Phase 4: Bubble Overlay

Required tasks:

- transparent non-activating bubble window
- placement from selection bounds
- field-level placement fallback
- hide/show rules from armed state
- click-to-open composer

Exit condition:

- bubble appears only when useful and never steals focus

### Phase 5: Composer Panel

Required tasks:

- compact panel window
- pinned preset tabs
- instruction input
- slash-based preset search
- submit and escape behavior

Exit condition:

- user can open panel from shortcut or bubble and submit a request without touching anything else

### Phase 6: Model Client

Required tasks:

- complete OpenAI-compatible client
- request building from config
- prompt assembly from preset plus selection
- timeout handling
- response parsing

Exit condition:

- a rewrite request succeeds against LM Studio from inside the app

### Phase 7: Replacement Engine

Required tasks:

- direct replacement path
- paste replacement path
- clipboard transaction safety
- focus restoration behavior
- fallback review behavior

Exit condition:

- successful update works in a practical set of target apps

### Phase 8: Hardening

Required tasks:

- blacklist handling
- secure field suppression
- better error states
- app compatibility fixes
- basic polish on panel transitions and dismissal

Exit condition:

- the product is usable daily without obvious breakage in the target app set

## Concrete File Responsibilities

### Near-Term `Mote` Files

- `Sources/Mote/App/MoteApp.swift`
  - main app entry
- `Sources/Mote/App/AppDelegate.swift`
  - startup wiring
- `Sources/Mote/Integration/SelectionWatcher.swift`
  - event intake and selection refresh orchestration
- `Sources/Mote/Integration/GlobalHotkeyMonitor.swift`
  - active shortcut handling
- `Sources/Mote/Overlay/SelectionBubbleController.swift`
  - bubble lifecycle and positioning
- `Sources/Mote/Overlay/ComposerPanelController.swift`
  - composer and result panel behavior

### Near-Term `MoteCore` Files

- `Sources/MoteCore/Accessibility/AXSelectionReader.swift`
  - selected text read and focus resolution
- `Sources/MoteCore/Accessibility/AXBoundsResolver.swift`
  - character or selection bounds lookup
- `Sources/MoteCore/Accessibility/AXReplacementWriter.swift`
  - direct write path
- `Sources/MoteCore/Replacement/ReplacementCoordinator.swift`
  - choose direct vs paste vs fallback
- `Sources/MoteCore/Replacement/PasteReplaceStrategy.swift`
  - clipboard-safe paste path
- `Sources/MoteCore/LLM/OpenAICompatibleClient.swift`
  - endpoint request execution
- `Sources/MoteCore/Prompt/PromptBuilder.swift`
  - final message construction

## Engineering Rules

1. Do not start with visual polish.
2. Do not build generalized provider abstractions before LM Studio works.
3. Do not add persistent history just because requests exist.
4. Do not treat bubble placement quality as more important than replacement correctness.
5. Do not block keyboard-only workflows behind mouse-oriented affordances.
6. Do not hide fallback states. Be explicit when Mote cannot safely apply a result.

## Testing Sequence

### First Wave

- TextEdit
- Notes
- Safari textareas
- Chrome textareas

### Second Wave

- Arc
- Slack
- Notion
- VS Code

### Third Wave

- Mail
- Obsidian
- Cursor

## Compatibility Notes

Expect app-specific quirks. The architecture must allow target-specific fixes without polluting the core mental model.

Acceptable pattern:

- app capability checks
- app blacklist entries
- placement fallback rules

Unacceptable pattern:

- hardcoding the product around one editor or one browser

## What Not To Ship Before MVP

Do not spend time on:

- sync
- login
- cloud storage
- prompt library UI
- long onboarding
- elaborate settings windows
- analytics surfaces
- theme customization
