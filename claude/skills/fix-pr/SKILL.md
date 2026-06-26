---
name: fix-pr
description: Read a pull request's review comments and land real fixes — one verified commit per finding, root-cause over per-file patches
effort: high
disable-model-invocation: true
---

You resolve outstanding review feedback on a pull request. You make *real* fixes — committed, verified, and pushed — not surface patches. You are an orchestrator: the actual edits are applied by the `story-fixer` sub-agent, so the bulk of the fixing never passes through your context. You triage, write the findings out for the fixer, then verify and commit what it lands. The house rules below are non-negotiable; follow them without being reminded.

## Step 1 — Confirm the working location

Before reading or editing anything, run `git rev-parse --show-toplevel` and `git branch --show-current`. Confirm you are in the worktree/branch that the PR was opened from, **not** the main repo path. If the current branch does not match the PR's head branch, stop and tell the user — do not edit files in the wrong directory. If you spawn any sub-agents, pass them this absolute path explicitly.

## Step 2 — Identify the PR

Scan the user's request for a PR reference (a full GitHub PR URL or `#NNN`). If none is present, derive it from the current branch:

```bash
gh pr view --json number,url,headRefName,baseRefName,title
```

If that finds no PR for the branch, stop and ask the user which PR to work on. Record the PR number, URL, head branch, and base branch.

## Step 3 — Fetch the review feedback

Pull every review thread, including its resolved state, so you only act on unresolved feedback. Inline review threads carry their `isResolved` flag through GraphQL (the REST comments endpoint does not):

```bash
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
owner=${repo%/*}; name=${repo#*/}
gh api graphql -f owner="$owner" -f name="$name" -F number=<PR> -f query='
  query($owner:String!,$name:String!,$number:Int!){
    repository(owner:$owner,name:$name){
      pullRequest(number:$number){
        reviewThreads(first:100){
          nodes{
            id isResolved isOutdated
            comments(first:50){nodes{databaseId author{login} path line body}}
          }
        }
        reviews(first:50){nodes{author{login} state body}}
      }
    }
  }'
```

Also read the PR-level review summaries (the `reviews` nodes above) — reviewers often raise points in the overall review body rather than as inline threads.

Build a working list of every **unresolved** thread plus any actionable point from the review bodies. Skip threads already marked `isResolved`. Note `isOutdated` threads but still read them — the concern may persist even if the line moved.

## Step 4 — Triage each finding

For each item, classify it before touching code:

- **Fix** — a genuine issue to resolve.
- **Already addressed** — the current code already satisfies it (a later commit fixed it). Note it for the hand-off; no code change.
- **Won't fix / discuss** — you disagree or it needs the author's judgement. Do not silently drop it; surface it to the user in the hand-off so they can decide and respond on the thread themselves.

If any finding's intent is ambiguous (which behaviour the reviewer wants, naming, scope), batch those questions and ask the user **once, up front**, before writing code — don't discover the mismatch after committing.

## Step 5 — Write the findings out for the fixer

Assign each **Fix** finding a short stable ID (`PR1`, `PR2`, …) and write all of them to a single section file, e.g. `/tmp/review-pr.md`, in the format the `story-fixer` agent greps for — one `### <ID>` block each:

```md
### PR1
Severity: Blocker
File: src/Foo/Bar.cs:123
Issue: <what the reviewer raised, in your words>
Fix: <the root-cause change to make, and the chokepoint to make it at>
```

The `Fix:` line is where you encode the house rules for the fixer: name the **single chokepoint** where the change belongs (not every call site), and call for the **idiomatic** change — never a non-idiomatic shortcut (e.g. exposing internal state as a public field) just to make it quick. Trace the root cause here, before dispatching, so the fixer lands one upstream change rather than per-file symptom patches.

## Step 6 — Dispatch the fixer, one commit per logical fix

Group the finding IDs into **commit units**: usually one finding per unit, but findings that share a single root-cause chokepoint go in one unit (a root-cause fix covering several findings is one logical commit). Work through the units **in order**. For each unit:

1. **Dispatch `story-fixer`** (Agent tool, `subagent_type: "story-fixer"`), passing:
   - The PR URL/`#NNN` — and note that this is a *pull request*, not a story issue: there are no spec/plan/learnings stickies, so it should use `gh pr view` for context.
   - The finding IDs in this unit.
   - The section file path (`/tmp/review-pr.md`).
   - The absolute worktree path from Step 1, so it edits in the right directory.
2. **Read its report.** It returns Fixed / Deviated / Skipped per ID and does not commit. If it reports a unit as wholly Skipped (the issue no longer exists, or the proposed fix would regress), make no commit and carry the reason to the hand-off.
3. **Verify before committing.** Run the project's build, tests, and linting/inspections for the area touched. Discover the exact commands from the repo's `CLAUDE.md` / steering docs — do not hardcode toolchain commands in this skill. Only commit if green; if it's red, the fixer's edit is incomplete — send the failure back to a fresh `story-fixer` dispatch for the same unit rather than committing.
4. **Commit the unit on its own.** One commit per logical fix — never a single combined commit across units. The message explains *why* (reference the review point), not just what.

## Step 7 — Push

1. Push the branch.
2. If the changes alter what the PR does, update the PR body to match.

Do **not** reply to or resolve review threads — the author handles replying and resolving themselves. Your job ends at pushed, verified commits.

## Step 8 — Hand off

Give the user a compact summary:
- Findings fixed, with the commit subject for each commit unit.
- Anything `story-fixer` reported as **Deviated** (a different fix than specified) or **Skipped**, with its one-line reason.
- Findings classified *Already addressed* or *Won't fix / discuss* in triage, with the one-line reason.
- Confirmation the branch is pushed and green. All review threads are left for the user to reply to and resolve themselves.
