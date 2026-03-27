# UX And Interaction

## Primary Interaction Model

Mote is selection-driven.

The product only becomes visible when the user has already selected text in an editable field or deliberately triggers the rewrite action through a shortcut while a valid selection exists.

## User Flows

### Flow A: Mouse-First

1. User selects text with the mouse.
2. Mote waits for the selection to stabilize.
3. A tiny bubble appears near the selection.
4. User clicks the bubble.
5. Composer panel opens.
6. User chooses a preset or types an instruction.
7. Model returns rewritten text.
8. User presses `Update`.
9. Mote replaces the original selection in place.

### Flow B: Keyboard-First

1. User selects text with the keyboard.
2. User presses the Mote global shortcut.
3. Composer panel opens immediately if the selection is valid.
4. User chooses a preset or types an instruction.
5. Model returns rewritten text.
6. User confirms replacement.

The keyboard-first flow is not secondary. It must be as fast and reliable as the mouse-first flow.

## Selection Sources That Must Be Supported

Mote must treat all normal selection methods as equal:

- mouse drag selection
- double-click word selection
- triple-click paragraph selection where supported
- `Shift + Arrow`
- `Option + Shift + Arrow`
- `Command + Shift + Arrow`
- `Command + A`
- standard platform text selection gestures exposed through Accessibility

The trigger condition is not a specific key. The trigger condition is a valid non-empty selection inside a writable text context.

## Interaction States

### Idle

No valid selection is present. No UI is visible.

### Armed

A valid non-empty selection exists in a supported editable field.

Behavior:

- bubble may appear if precise placement is available
- global shortcut may open the composer immediately

### Composing

The compact panel is open and accepts user intent.

The panel contains:

- pinned preset tabs along the top
- a small text input for custom instruction
- slash-based preset search inside the input
- submit action

### Resolving

The request is in flight.

Behavior:

- input is disabled or visually locked
- there is a clear loading state
- the current selection context is preserved

### Review

The model result is available.

Behavior:

- rewritten text is shown
- actions are limited to `Cancel` and `Update`
- no full chat transcript is shown

### Applied

The replacement succeeds.

Behavior:

- panel closes
- focus returns to the original app
- Mote returns to idle

### Fallback Review

Used when direct in-place replacement is not available.

Behavior:

- show rewritten text
- allow copy-based fallback or paste-based update when feasible
- make the failure mode explicit without pretending to have applied the change

## Bubble Behavior

### Purpose

The bubble is a tiny inline affordance that signals “rewrite this selection”. It is not a toolbar.

### Appearance

- minimal circular or rounded shape
- visible only when needed
- non-intrusive
- does not steal focus

### Placement

Primary placement target:

- near the start edge of the selected text bounds

Fallback placement target:

- near the editable field bounds when character-level bounds are unreliable

If placement is not trustworthy, do not show the bubble. The shortcut path must remain available.

### Timing

Bubble appearance should be slightly delayed after selection change to avoid flashing during active selection manipulation.

Recommended stabilization window:

- `80ms` to `150ms`

## Composer Panel

### Requirements

- small
- rounded
- focused on one action
- keyboard-friendly
- no history pane
- no unnecessary controls

### Content

- pinned preset tabs
- instruction input
- slash menu for presets
- submit control

### Input Rules

- `Enter` submits
- `Escape` closes
- typing `/` opens preset search
- empty input uses the selected preset template as-is

## Result Review Panel

The result state should be extremely small.

Required actions:

- `Cancel`
- `Update`

The UI should not turn into a diff workstation.

## Trigger Matrix

### Passive Triggers

These should refresh selection state and potentially show the bubble:

- left mouse up after selection change
- focused element change
- selected text change notification from Accessibility
- keyboard selection completion events

### Active Triggers

These should open the composer directly if a valid selection exists:

- user-defined global shortcut
- optional experimental `Fn` trigger

### Keyboard Selection Events That Must Cause Refresh

- `Command + A`
- `Shift + Arrow`
- `Option + Shift + Arrow`
- `Command + Shift + Arrow`
- any standard navigation shortcuts that change the selected range

The system should use debounced refresh rather than immediate synchronous reads after every key event.

## Full Selection Behavior

When the user uses `Command + A`, the entire field may be selected.

Rules:

- if the field is editable and valid, Mote should treat the selection as normal
- if character-level bounds are poor, the bubble may anchor to the field instead of the text start
- if even field-level placement is unstable, skip the bubble and rely on the shortcut path

## Failure And Fallback UX

### If Mote Cannot Read Selection Bounds Reliably

- still allow shortcut-driven composer if selected text is readable
- do not show a misleading bubble

### If Mote Can Read But Cannot Write Back Directly

- present result review
- use paste-based replacement when safe
- otherwise offer copy-only fallback

### If Mote Detects Secure Field Or Blacklisted App

- do nothing visibly
- do not surface the bubble
- do not attempt to open the composer for that target

## Preset UX

Pinned tabs should represent the highest-frequency actions only.

Initial pinned presets:

- `Translate`
- `GitHub`
- `Shorten`

Slash menu should expose the same presets and any future custom presets.

## Interaction Design Rules

1. Bubble is optional. Shortcut path is mandatory.
2. Keyboard-driven users must never be forced to move to the mouse.
3. Replacement confirmation must be fast and obvious.
4. Mote must leave the user inside the original app after completion.
5. No persistent UI should remain after the action completes.
