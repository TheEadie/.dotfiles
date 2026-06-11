---
name: implement-wip
description: Orchestrate planning, implementation, and an automated review-fix loop for a slice issue
effort: medium
disable-model-invocation: true
---

You coordinate the full slice workflow: plan → implement → review → hand off. Every phase runs in its own sub-agent (`slice-planner-wip`, `slice-implementer-wip`, `review-coordinator-wip`), so this orchestrator holds almost no phase output in context. The entire review-and-fix loop — `/code-review high --fix`, the spec and toolchain reviewers, `review` sticky assembly, and the `slice-fixer-wip` ↔ rereview loop — lives inside `review-coordinator-wip`, which returns only a compact summary. Each sub-agent's frontmatter pins the model it runs on.

Sub-agents in this harness *can* spawn further sub-agents, so the review coordinator is free to run the parallel reviewer fan-out and invoke `/code-review` (which fans out internally) from inside its own context — none of that bulky output passes through this orchestrator.

## Sticky comment operations

Sticky comments are GitHub issue comments identified by a hidden HTML-comment marker on the first line: `<!-- claude:sticky:<name> -->`. Subsequent runs find and update the existing comment by marker.

Use the `gh-sticky` helper for every sticky operation — it wraps the lookup-then-PATCH-or-create dance in a single approved command so the sandbox doesn't prompt on each invocation. Do not chain `gh api` calls inline.

**Read a sticky** (prints `{id, body, url}` JSON, or `null` if none):
```bash
~/.claude/scripts/gh-sticky get <number> <name>
```

There are also `get-id`, `get-body` (prints body to stdout), and `save <number> <name> <file>` (writes body to file) for narrower needs. Use whichever produces the least context noise.

**Write (create-or-update) a sticky:**
1. Render the full body to `/tmp/sticky-<name>.md` with the marker as the first line.
2. Run `~/.claude/scripts/gh-sticky upsert <number> <name> /tmp/sticky-<name>.md` — the helper looks up an existing sticky by marker and either PATCHes it or creates a new comment.

The helper refuses to write if the body file's first line isn't the matching marker, so always render to the temp file first.

**Fetch parent epic and sibling sub-issues:**
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER=${REPO%/*}
NAME=${REPO#*/}
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        parent {
          number title body url
          subIssues(first: 100) { nodes { number title state } }
        }
      }
    }
  }' -f owner="$OWNER" -f repo="$NAME" -F number=<slice-issue-number>
```

## Step 1 — Identify the slice issue

Scan the user's request for a GitHub issue reference (a full GitHub issue URL, or a `#NNN` token). If none is present, stop and ask the user which issue to work on. Do not proceed without an explicit issue reference.

Fetch the issue and inspect its sticky comments (using the operations above) to determine which phases need to run:

- `spec` sticky exists but no `plan` sticky → planning + implementing + review-fix loop
- `plan` sticky exists but no `learnings` sticky → implementing + review-fix loop
- `learnings` sticky exists but no `review` sticky → review-fix loop
- All three stickies (`plan`, `learnings`, `review`) exist → nothing left to run; go straight to Step 5 (hand off) against the existing `review` sticky

If no `spec` sticky exists AND no `plan` sticky exists, stop and tell the user to run `/spec` against this issue first.

Record the issue URL and number as `<issue>` for use below. Proceed immediately without asking the user to confirm.

## Step 2 — Plan phase

Skip if the `plan` sticky comment already exists on the issue.

Dispatch the `slice-planner-wip` agent (via the Agent tool with `subagent_type: "slice-planner-wip"`), passing the issue URL/number `<issue>` in the prompt.

## Step 3 — Implement phase

Skip if the `learnings` sticky comment already exists on the issue.

Dispatch the `slice-implementer-wip` agent (via the Agent tool with `subagent_type: "slice-implementer-wip"`), passing the issue URL/number `<issue>` in the prompt.

## Step 4 — Review-and-fix loop

Skip this entire step if the `review` sticky comment already exists on the issue.

Dispatch the `review-coordinator-wip` agent (via the Agent tool with `subagent_type: "review-coordinator-wip"`). 

Pass it:
- The issue URL/number `<issue>`.
- The base branch (default `main`) and the current branch.

## Step 5 — Hand off

Relay the review coordinator's compact summary to the user:
- How many review iterations ran and whether the loop converged or hit the 3-iteration cap
- How many findings the loop auto-fixed (and any that `slice-fixer-wip` reported as Deviated or Skipped)
- Whether any unresolved Blockers or pending findings remain (visible in the `review` sticky)
- Next step: run `/pr` to create the pull request

Do not commit, push, or open a PR — the user triggers that.
