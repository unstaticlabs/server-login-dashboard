---
name: preserving-decision-rationale
description: "Captures or reconstructs durable technical and operational decision rationale from repository evidence. Use when the user asks to record why a choice, constraint, workaround, or abandoned approach exists, or to recover that history for maintainers. Do not use for transient handoffs or generalized lessons."
license: MIT
metadata:
  usl-owner: unstatic-labs
  usl-version: "0.1.0"
  usl-status: experimental
  usl-risk: low
  usl-source: "https://github.com/oliver-zehentleitner/keep-the-why/tree/034d4b0b422d162b5975fc06b418d3feeea18aaf/skills/keep-the-why"
---

# Preserving Decision Rationale

Preserve why a durable choice exists without turning project history into an unverified narrative.

## Establish evidence

Use the strongest available sources in order: direct user or decision record, linked issue or review discussion, commit message and history, tests and comments, then current code structure. Treat the last two as clues, not proof of original intent.

Separate:

- confirmed context and constraints;
- alternatives demonstrably considered;
- rationale and tradeoffs;
- inferred explanation with confidence;
- unknowns that still need an owner.

Never invent a rejected alternative or silently convert inference into fact.

## Capture

Find the repository's existing home for ADRs, design notes, issue links, or focused comments. Add rationale where future maintainers will encounter the decision and keep the code as the source for what it does.

Record only durable information: decision, context, alternatives, why this option won, accepted consequences, evidence, current status, and a concrete revisit condition. Avoid session chronology, implementation diaries, and restating the code.

When a decision changes, preserve the earlier record and mark it superseded with a link to the replacement. Do not rewrite history as though the previous constraints never existed.

## Recover

When asked why existing code is present, trace relevant history and surrounding evidence. Return the best-supported explanation with citations and confidence. If the rationale cannot be recovered, state that explicitly and offer the current tradeoff analysis as a new decision, not historical fact.

## Boundaries

- Use a handoff for transient state and next actions.
- Use an engineering lesson for a conditional heuristic intended to transfer beyond this decision.
- Do not create a new documentation convention when an existing one is adequate.

## Output contract

Deliver a repository-native rationale record or an evidence-backed recovery report that distinguishes fact, inference, unknowns, consequences, and revisit conditions.
