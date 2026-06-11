---
name: implement-wip
description: Orchestrate planning, implementation, an automated review-fix loop, and interactive resolution of any leftovers for a slice issue
effort: medium
disable-model-invocation: true
---

You coordinate the full slice workflow: plan → implement → (review ↔ fix)* → resolve. The plan and implement phases run in their own sub-agents (`slice-planner-wip`, `slice-implementer-wip`). The review phase begins by invoking the built-in `/code-review high --fix` skill — which covers correctness, security, simplification, and efficiency and applies fixes inline — then dispatches `reviewer-spec-wip` plus the toolchain gates (`reviewer-csharp-wip`, `reviewer-react-wip`) in parallel. Each reviewer writes its full findings section to a temp file and returns only a compact summary, so the orchestrator assembles the `review` sticky by concatenating those files with shell — it never holds the verbatim findings in context. The loop alternates with `slice-fixer-wip` until the slice converges — no Blockers and no Accept-recommended Suggestions remain — or a hard cap is hit. The resolution phase then runs interactively in this session for whatever's left (Nitpicks, Declines, and any auto-fixable findings the cap cut off). Each sub-agent's frontmatter pins the model it runs on.

The review phase is deliberately kept lean in this orchestrator's context: sub-agents can't spawn sub-agents, so the parallel reviewer fan-out has to live here, but the bulky verbatim output does not. Reviewers return compact summaries; full bodies live in `/tmp/review-*.md` files and reach the sticky only through the shell-concatenation step below.

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

- `spec` sticky exists but no `plan` sticky → planning + implementing + review-fix loop + interactive resolution
- `plan` sticky exists but no `learnings` sticky → implementing + review-fix loop + interactive resolution
- `learnings` sticky exists but no `review` sticky → review-fix loop + interactive resolution
- All three stickies (`plan`, `learnings`, `review`) exist → only Step 5 (interactive resolution) runs against the existing `review` sticky

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

You will run up to **3 total review iterations** (one initial review + up to 2 fix-then-rereview passes). The loop exits as soon as the latest review contains no auto-fixable findings, or when the iteration cap is hit. Track the iteration count explicitly.

### File classification

Determine the base branch (default `main`) and current branch. Run:

```bash
git diff --name-only <base>...<current-branch>
```

Classify the results:

- **C# files** — `*.cs`, `*.csproj`, `*.razor`, `*.sln`, `Directory.*.props`/`targets`.
- **Web files** — files under the repo's web project directory (check `CLAUDE.md` to identify it — typically a directory with `package.json` at its root).
- **Other** — migrations, Docker, infra, docs, CI workflow files.

Identify which component(s) the C# files belong to by the project directory names they sit under (e.g. a file under `src/Foo.Bar/` belongs to the `Foo.Bar` component). Check `CLAUDE.md` for a component-to-doc mapping.

Record the base branch, current branch, C# file list, web file list, and component list — reuse these in every review iteration without re-running the diff.

All review bodies live in `/tmp/review-*.md` files so they never enter this context. The orchestrator owns three of them; each reviewer sub-agent owns one:

- `/tmp/review-codereview.md` — `/code-review` findings (orchestrator writes, once).
- `/tmp/review-spec.md` — `reviewer-spec-wip`'s section (Acceptance Criteria, Blockers, Suggestions, Nitpicks).
- `/tmp/review-csharp.md` — `reviewer-csharp-wip`'s section. Absent if not dispatched.
- `/tmp/review-web.md` — `reviewer-react-wip`'s section. Absent if not dispatched.
- `/tmp/review-verdict.md` — the Verdict paragraph (orchestrator writes each iteration).
- `/tmp/review-actions.md` — the Recommended Actions list (orchestrator writes each iteration).

### Iteration 1 — initial review

**Phase A — code-review with auto-fix.** Invoke the built-in `/code-review high --fix` skill (via the Skill tool). It reviews the diff for correctness, security, simplification, and efficiency, then applies its findings to the working tree. When it returns, **immediately Write its verbatim findings to `/tmp/review-codereview.md`** (the body that will sit under the `## Code Review` heading; if it reported nothing, write `None`) and note the fix count for the verdict. This is the one place `/code-review` output passes through your context — getting it onto disk now means you don't re-hold it when you assemble the sticky.

> **Do not stop when `/code-review` returns.** Invoking `/code-review` is a *sub-step* of this skill, not a handoff back to the user. The code-review skill ends with its own "what was fixed / what was skipped" summary — **that summary is NOT the end of `/implement-wip`, even when it found nothing to fix.** The moment it returns, you are still the orchestrator mid-Step-4: in the *same turn*, without yielding to the user, proceed directly to Phase B below. Treating the code-review summary as a turn boundary is the most common way this skill stalls — do not do it.

This phase runs once at the start of Step 4 only. Subsequent loop iterations skip it and leave `/tmp/review-codereview.md` untouched; the in-loop fixes come from `slice-fixer-wip` acting on findings from Phase B.

**Phase B — spec + toolchain reviewers.** After Phase A completes, dispatch the remaining reviewer sub-agents in a **single message** (parallel). Tell each one the absolute path to write its full section to, and rely on it returning **only a compact summary** (a one-line verdict plus a findings index — one line per finding: `<ID> | <severity> | <file:line> | <short title>`):

1. **Always** spawn `reviewer-spec-wip` (via the Agent tool with `subagent_type: "reviewer-spec-wip"`) with: the GitHub issue URL, the base branch, the current branch, and the section-file path `/tmp/review-spec.md`.
2. **If any C# files changed**, spawn `reviewer-csharp-wip` (via the Agent tool with `subagent_type: "reviewer-csharp-wip"`) with: the base branch, the current branch, the C# file list, the component(s), and the section-file path `/tmp/review-csharp.md`.
3. **If any web files changed**, spawn `reviewer-react-wip` (via the Agent tool with `subagent_type: "reviewer-react-wip"`) with: the base branch, the current branch, the web file list, the web project directory, and the section-file path `/tmp/review-web.md`.

Keep only the compact summaries in context — never read the section bodies back in. Reviewers use globally-unique, axis-prefixed IDs (`Spec B1`, `C# B1`, `Web B1`), so the index is unambiguous as-is.

**Assemble the `review` sticky.** Decide a one-line `Accept` or `Decline` recommendation for every finding in the compact index, summarising all axes honestly (a Spec-pass / toolchain-fail reads very differently from a Spec-fail / toolchain-pass). Then build the sticky from files, without pulling the section bodies into context:

1. Write the Verdict paragraph to `/tmp/review-verdict.md` — summarise every axis from the compact summaries, and note that `/code-review high --fix` ran and applied N fixes (if known) and any blockers the user must address before merging.
2. Write the Recommended Actions list to `/tmp/review-actions.md` — one `- **<ID>** — Accept|Decline — [reason]` line per finding, covering every finding.
3. Concatenate the pieces with shell (the sticky marker must be line 1; the blank lines the `printf`s emit are required for GitHub to render the inner markdown):

```bash
{
  printf '<!-- claude:sticky:review -->\n\n# Review\n\n_Generated by Claude Code._\n\n<details>\n<summary>Show review</summary>\n\n## Verdict\n\n'
  cat /tmp/review-verdict.md
  printf '\n\n## Code Review\n\n'; cat /tmp/review-codereview.md
  printf '\n\n## Spec\n\n'; cat /tmp/review-spec.md
  [ -f /tmp/review-csharp.md ] && { printf '\n\n## C# Toolchain\n\n'; cat /tmp/review-csharp.md; }
  [ -f /tmp/review-web.md ] && { printf '\n\n## Web Toolchain\n\n'; cat /tmp/review-web.md; }
  printf '\n\n## Recommended Actions\n\n'; cat /tmp/review-actions.md
  printf '\n\n</details>\n'
} > /tmp/sticky-review.md
```

4. Upsert it: `~/.claude/scripts/gh-sticky upsert <number> review /tmp/sticky-review.md`. The `<details>` wrapper keeps the comment collapsed to a one-line header on the issue.

### Loop

Repeat the following until either the auto-fixable list is empty or you have completed 3 review iterations:

1. From the compact findings index of the latest Phase B and the recommendations you assigned, **collect the auto-fixable findings** — every finding whose severity is `Blocker` or `Suggestion` *and* whose recommendation is `Accept`. **Do not include Nitpicks. Do not include Declines.** These stay for the user in Step 5.
2. If the auto-fixable list is **empty**, exit the loop and proceed to Step 5.
3. If you have already completed **3 review iterations** in total, exit the loop and proceed to Step 5 — note in your hand-off that the cap was hit so the user knows there may still be auto-fixable items left.
4. Dispatch the `slice-fixer-wip` agent (via the Agent tool with `subagent_type: "slice-fixer-wip"`), passing the issue URL/number `<issue>`, the list of auto-fixable finding **IDs**, and the section-file paths (`/tmp/review-spec.md`, plus `/tmp/review-csharp.md` and/or `/tmp/review-web.md` if they exist). It reads each finding's full detail from those files by ID — do **not** copy verbatim findings into the prompt. (The files still hold the latest Phase B findings at this point; the next Phase B overwrites them only afterwards.)
5. After `slice-fixer-wip` returns, re-dispatch the Phase B reviewer sub-agents in parallel (same inputs and section-file paths) to produce a fresh review against the updated code. They overwrite their section files. Do **not** re-run `/code-review` and do **not** touch `/tmp/review-codereview.md` — Phase A is a once-per-Step-4 step. Regenerate `/tmp/review-verdict.md` and `/tmp/review-actions.md` from the new compact summaries, re-run the assembly shell block, and upsert. This is the next review iteration — increment your counter. Verify the `review` sticky comment has been updated.
6. Go back to step 1.

Briefly tell the user when each iteration begins and ends, including which findings went to `slice-fixer-wip` and what `slice-fixer-wip` reported back (Fixed / Deviated / Skipped). Do not surface the full review body — the user can read the sticky if they want detail.

## Step 5 — Report remaining findings

By the time you reach this step, the loop has driven the slice to either zero auto-fixable findings or the iteration cap. Proceed directly to Step 6 — do not ask the user to resolve findings interactively.

## Step 6 — Hand off

Tell the user:
- How many review iterations ran and whether the loop converged or hit the 3-iteration cap
- How many findings the loop auto-fixed (and any that `slice-fixer-wip` reported as Deviated or Skipped)
- Whether any unresolved Blockers or pending findings remain (visible in the `review` sticky)
- Next step: run `/pr` to create the pull request

Do not commit, push, or open a PR — the user triggers that.
