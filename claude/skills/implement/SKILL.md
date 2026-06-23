---
name: implement
description: Orchestrate planning, implementation, and an automated review-fix loop for a slice issue
effort: medium
disable-model-invocation: true
---

You coordinate the full slice workflow: plan → implement → review → hand off. Every phase runs in its own sub-agent (`slice-planner`, `slice-implementer`, `review-coordinator`), so this orchestrator holds almost no phase output in context. The entire review-and-fix loop — `/code-review high --fix`, the spec and toolchain reviewers, `review` sticky assembly, and the `slice-fixer` ↔ rereview loop — lives inside `review-coordinator`, which returns only a compact summary. Each sub-agent's frontmatter pins the model it runs on.

Sub-agents in this harness *can* spawn further sub-agents, so the review coordinator is free to run the parallel reviewer fan-out and invoke `/code-review` (which fans out internally) from inside its own context — none of that bulky output passes through this orchestrator.

## Sticky comment operations

This orchestrator only *reads* stickies — to decide which phases still need to run; the sub-agents do all the writing. Use the `gh-sticky` helper (`~/.claude/scripts/gh-sticky`, run with no args for usage) — never chain `gh api` calls inline. To check whether a sticky exists, `gh-sticky get-id <number> <name>` prints its comment id or empty (the least context noise of the read variants).

## Step 1 — Identify the slice issue

Scan the user's request for a GitHub issue reference (a full GitHub issue URL, or a `#NNN` token). If none is present, stop and ask the user which issue to work on. Do not proceed without an explicit issue reference.

Fetch the issue and inspect its sticky comments (using the operations above) to determine which phases need to run:

- `spec` sticky exists but no `plan` sticky → planning + implementing + review-fix loop
- `plan` sticky exists but no `learnings` sticky → implementing + review-fix loop
- `learnings` sticky exists but no `review` sticky → review-fix loop
- All three stickies (`plan`, `learnings`, `review`) exist → nothing left to run; go straight to Step 6 (hand off) against the existing `review` sticky

If no `spec` sticky exists AND no `plan` sticky exists, stop and tell the user to run `/spec` against this issue first.

Record the issue URL and number as `<issue>` for use below. Proceed immediately without asking the user to confirm.

## Step 2 — Create the worktree

Skip if there is nothing left to run (the `plan`, `learnings`, and `review` stickies all already exist — i.e. Step 1 sent you straight to hand off).

Create an isolated git worktree for this slice with the `EnterWorktree` tool. Derive a short, descriptive kebab-case name from the issue's title/feature (e.g. `add-csv-export`, `fix-login-redirect`), not the issue number. All subsequent phases run inside this worktree. Do not exit the worktree — leave it intact so the user can review, run `/pr`, and clean it up when done.

## Step 3 — Plan phase

Skip if the `plan` sticky comment already exists on the issue.

Dispatch the `slice-planner` agent (via the Agent tool with `subagent_type: "slice-planner"`), passing the issue URL/number `<issue>` in the prompt.

## Step 4 — Implement phase

Skip if the `learnings` sticky comment already exists on the issue.

Dispatch the `slice-implementer` agent (via the Agent tool with `subagent_type: "slice-implementer"`), passing the issue URL/number `<issue>` in the prompt.

## Step 5 — Review-and-fix loop

Skip this entire step if the `review` sticky comment already exists on the issue.

Dispatch the `review-coordinator` agent (via the Agent tool with `subagent_type: "review-coordinator"`). 

Pass it:
- The issue URL/number `<issue>`.
- The base branch (default `main`) and the current branch.

## Step 6 — Hand off

Relay the review coordinator's compact summary to the user:
- How many review iterations ran and whether the loop converged or hit the 3-iteration cap
- How many findings the loop auto-fixed (and any that `slice-fixer` reported as Deviated or Skipped)
- Whether any unresolved Blockers or pending findings remain (visible in the `review` sticky)
- Next step: run `/pr` to create the pull request

Do not commit, push, or open a PR — the user triggers that.
