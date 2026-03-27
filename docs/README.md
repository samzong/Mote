# Mote Docs

Mote is a background macOS agent that lets users rewrite selected text anywhere.

This documentation set is intended to be implementation-complete. A new engineer should be able to build the MVP directly from these documents without needing prior conversation context.

## Reading Order

1. `FOUNDATION.md`
   Product definition, scope, naming, design principles, and non-goals.
2. `UX_AND_INTERACTION.md`
   User flows, trigger matrix, overlay behavior, keyboard-first behavior, and panel states.
3. `SYSTEM_ARCHITECTURE.md`
   Runtime architecture, module responsibilities, configuration format, model API contract, and replacement strategies.
4. `IMPLEMENTATION_PLAN.md`
   Phase-by-phase execution order, milestones, file layout, and concrete engineering tasks.
5. `ACCEPTANCE_CRITERIA.md`
   What must be true before the MVP can be called real.

## One-Line Product Definition

Mote is a system-wide rewrite layer for selected text on macOS.

## Target Outcome

A user can select text inside a normal editable field in most macOS apps, trigger Mote with either a tiny inline affordance or a keyboard shortcut, ask for a rewrite using a pinned preset or a short instruction, and replace the selected text in place with the model output.
