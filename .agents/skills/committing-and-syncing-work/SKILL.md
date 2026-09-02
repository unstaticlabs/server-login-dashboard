---
name: committing-and-syncing-work
description: "Creates verified, atomic Conventional Commits and synchronizes them according to repository policy. Use when the user asks to commit, push, sync, split commits, or write a commit message, or when `.usl/agent-policy.json` enables automatic checkpoints after verified changes. Do not commit ordinary work automatically when repository policy disables it."
license: MIT
metadata:
  usl-owner: unstatic-labs
  usl-version: "0.1.0"
  usl-status: experimental
  usl-risk: high
  usl-source: "https://github.com/softaworks/agent-toolkit/tree/3027f20f3181758385a1bb8c022d4041dfb4de84/skills/commit-work"
---

# Committing and Syncing Work

Create reviewable recovery points without capturing someone else's changes or turning synchronization into silent history rewriting.

## Resolve repository policy

Read [the repository policy](references/repository-policy.md) from the repository root. A current explicit user instruction overrides saved policy for this task but does not change the saved preference unless requested.

If the policy file is absent when a commit or automatic-checkpoint decision is needed, ask once for `auto_commit` and `auto_push`, then persist the answer at `.usl/agent-policy.json`. Do not infer permission from another repository, a global preference, or the existence of this skill.

## Choose a checkpoint

An automatic commit is justified after a coherent verified result, before a risky transformation or context handoff, or at task completion. Do not checkpoint every save, knowingly broken intermediate state, or unrelated cleanup.

Split by independently understandable and reversible intent, not file count. Keep implementation with the tests and documentation required to explain or verify that same behavior. Separate unrelated features, refactors, generated churn, and dependency changes.

## Prepare the commit

- Inspect the full working tree before staging. Distinguish agent-owned work from pre-existing or concurrent user changes.
- Stage only the intended paths or hunks. If mixed changes cannot be isolated safely, stop the automatic commit and report why.
- Review the staged diff for scope, secrets, debug artifacts, accidental formatting, generated files, and misleading omissions.
- Run the smallest meaningful repository checks. Automatic commits require a coherent result and passing relevant checks; an explicit request may accept a known failure only when it is disclosed and the commit message remains truthful.

Use Conventional Commits:

```text
type(scope): imperative plain-language summary
```

Use the established project vocabulary and the narrowest accurate type. Add a body only when rationale, tradeoffs, migration, or non-obvious limitations help a reviewer. Mark breaking changes explicitly. Avoid implementation diaries, decorative language, and generated-by disclaimers.

## Synchronize safely

After a commit, apply `auto_push` or the current explicit request:

- fetch the selected remote and identify the branch's upstream and remote default branch;
- `never`: do not push automatically;
- `non-default`: push automatically only when the current branch is not the remote default branch;
- `always`: push automatically, including the default branch;
- when no upstream exists, set one only if the remote and target branch are unambiguous and policy permits the push.

If the remote is empty, ambiguous, ahead, or diverged, stop and request the necessary decision. Never force-push, bypass hooks, silently merge or rebase, move tags, or discard work. A rejected push remains unpushed until its cause is resolved explicitly.

## Output contract

Report each commit's short SHA and message, verification performed, push target and result, policy applied, and any intentionally uncommitted changes or unresolved synchronization state.
