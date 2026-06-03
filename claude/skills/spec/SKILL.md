---
name: spec
description: Turn one slice (a GitHub issue) into a focused, implementable spec written as a sticky comment on the issue
effort: high
disable-model-invocation: true
---

Your task is to flesh out a slice's GitHub issue into a complete, unambiguous specification, and write that spec as a sticky comment on the issue. The spec will be reviewed by a colleague (human or AI) before implementation, so it must be unambiguous and complete.

YOU DO NOT IMPLEMENT THE USER'S REQUEST. Only write the sticky comment to the GitHub issue.

## Step 1 — Identify the slice issue

Scan the user's request for a GitHub issue reference (a full GitHub issue URL, or a `#NNN` token). If none is present, stop and ask the user which issue this spec is for. Do not proceed without an explicit issue reference.

Once you have an issue number, fetch it:

```bash
gh issue view <number-or-url> --json number,title,body,url
```

Read the current issue body as context — it may be a one-sentence stub or a prior draft. Record the issue number and URL for use in Step 5.

A slice is intended to be a small, deliverable chunk that ships as a single PR — not a large epic. If it seems too big, challenge the user to break it down and begin with a smaller first step. See "If the slice is too large" below.

## Step 2 — Learn the codebase context

Before writing anything, read the following to understand how the slice fits the existing system:

- The root `CLAUDE.md` — use it as an index. It should point to any steering docs (coding guidelines, testing strategy, CI patterns, architecture) and component docs relevant to this area. Read whichever of those docs apply to the slice.
- Any source files directly relevant to the slice area.
- Query the slice's parent epic via GraphQL:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER=${REPO%/*}
NAME=${REPO#*/}

gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        parent {
          number
          title
          body
          url
          subIssues(first: 100) {
            nodes { number title state }
          }
        }
      }
    }
  }' -f owner="$OWNER" -f repo="$NAME" -F number=<slice-issue-number>
```

If a parent exists, read its body — the slice must sit consistently within the epic's goals, non-goals, and major capabilities. If `parent` is `null`, treat this as a standalone slice with no enclosing epic.

If the user's request appears to contradict the parent epic or to skip ahead in the delivery order (judged by the position of this slice among its siblings in `parent.subIssues`), raise that with them before continuing.

## Step 3 — Establish the simplest viable approach

The default position is always the simplest thing that meets the stated need.

Before probing for detail, identify the simplest version of the slice and present it to the user. Then identify any aspects of the request that could be implemented in a more complex or robust way — things like validation, error handling, configuration options, edge case coverage, or extensibility.

Walk through these one at a time, asking the user whether each should be included. For each one, give your recommended answer (usually "leave it out for this slice") with a brief reason, so the user can react to a concrete proposal. Ask one question per turn and wait for the answer before moving to the next — do not bundle them into a single list. If a question can be answered by exploring the codebase rather than asking the user, do that instead. Do not assume more is better.

If the user's initial request already contains complexity that isn't strictly necessary to deliver the slice, surface that and ask whether it can be simplified or deferred to a later slice.

## Step 4 — Grill the user until the spec is watertight

Interview the user relentlessly about every aspect of this slice until you reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one. Follow each branch where it leads — if a happy-path question surfaces an error case or edge case, chase it down then rather than deferring it to a later "round".

**How to ask:**

- Ask questions **one at a time** — never bundle multiple questions into a single turn. Wait for the answer before moving on.
- For each question, **provide your recommended answer** along with the question, so the user can react to a concrete proposal rather than starting from a blank slate. Explain briefly why you recommend it.
- If a question can be answered by **exploring the codebase**, explore it instead of asking the user. Only ask when the answer genuinely requires the user's intent or knowledge.
- After each answer, if the spec content is now settled for that point, fold it into the relevant section straight away rather than batching at the end.

**Areas to make sure you cover.** This is not a script to read through in order — it's a checklist of categories the spec must address before you can exit this step. Use it to notice gaps that the decision-tree walk would otherwise miss.

- **Core behaviour and happy path** — which components/projects are affected; what data flows in and out and in what format; how the user discovers or triggers the feature; what "success" looks like from the user's perspective.
- **Error cases and failure modes** — for every operation the slice performs: what if required data is missing or malformed; what if a network call, database query, or external service fails; what if the user triggers the action in the wrong state or without permission; what if two actions happen concurrently.
- **Edge cases and boundaries** — empty / zero states; single vs. many; large data and input-size limits; ordering and timing (sequence, out-of-order events); transitions (navigate away, refresh, cancel mid-flow); repeated actions (double-submit, duplicate event processing); stale data (acting on data that has since changed).

For each item the slice touches, confirm the expected behaviour — do not leave it as "TBD". If something genuinely doesn't apply to this slice (e.g. there are no concurrency concerns because the slice is read-only), note that and move on.

**Scope and deferral sweep.** When you believe you're done, review every answer and ask yourself: are there any remaining ambiguities, implicit assumptions, or "it depends" answers that have not been pinned down? If yes, ask those questions now (one at a time, with a recommended answer). Repeat the sweep until the answer is no.

Do not proceed to Step 5 until you can answer "yes" to all of the following:

- Every requirement has a clear, unambiguous description.
- Every error case has a specified outcome.
- Every edge case surfaced during the interview either has a defined behaviour or has been explicitly deferred by the user.
- The "Open Questions" section of the spec will either be empty or contain only items the user has deliberately chosen to leave unresolved.
- If the slice includes any UI page or visual component: the design mockup has been reviewed and approved. If the design is still in flux, the spec must flag which visual details are pending and explicitly defer them rather than describing a placeholder that will need wholesale replacement later.
- If the slice introduces a capability for the first time (a new test framework, a new CI job category, a new make target category): the setup of that infrastructure is explicitly included in scope and its files are listed. Do not assume it can be added invisibly.
- If the slice adds or extends an endpoint that returns a richer response type for a single item while a corresponding list endpoint exists: a scope decision has been made and recorded — either the list endpoint is updated in this slice or the asymmetry is explicitly deferred.

## Step 5 — Write the spec as a sticky comment

Render the spec using the template below to `/tmp/spec-body.md`. The first line MUST be the sticky marker:

```
<!-- claude:sticky:spec -->
```

Followed by a blank line, then the rendered markdown.

Then create or update the sticky comment on the issue with the `gh-sticky` helper (it handles the look-up-then-PATCH-or-create dance in a single approved command — do not chain `gh api` calls manually):

```bash
~/.claude/scripts/gh-sticky upsert <number> spec /tmp/spec-body.md
```

The helper refuses to write if the body file's first line isn't the sticky marker, so always pass the body via the temp file — never construct comment text inline. Capture the issue URL for Step 6.

### Spec body template

```markdown
<!-- claude:sticky:spec -->

# Spec

_Generated by Claude Code._

## Overview

[One or two sentences describing what is delivered and why.]

## Requirements

[Bulleted list of capabilities and behaviours that must exist. Written from the user/requirements perspective — what the system must do, not how it does it.]

## Out of Scope

[Explicit list of related things this slice does NOT include. This is as important as the requirements — it prevents reviewers from making different assumptions about scope.]

## Acceptance Criteria

[Bulleted list of conditions that must be true for the slice to be considered complete. Written as observable outcomes: "Given X, when Y, then Z." Each requirement above should map to at least one criterion here.]

## Open Questions

[Any unresolved ambiguities the user has explicitly chosen to defer — not items that were never asked. If you have reached Step 5, this section should be empty or contain only deliberate deferrals. Do not write the spec if you still have unanswered questions; go back to Step 4.]
```

### Rules for the spec content

- Focus on WHAT is needed, not HOW to build it
- Never add anything the user didn't explicitly ask for
- Default to the simplest approach — only include complexity the user explicitly agreed to in Step 3
- Do not include implementation details such as class names, function signatures, interfaces, or code structure — those belong in the implementation plan
- Do not prescribe the technical approach
- Every requirement must have at least one acceptance criterion

## Step 6 — Hand off

Tell the user the issue URL and that the spec is ready for implementation with `/implement`. Do not commit, branch, or open a PR — the existing `/pr` skill handles that once code changes exist. Do not close the issue — it stays open until the implementing PR merges.

## If the slice is too large

If the slice is too large to be a single PR-sized deliverable, you MUST suggest breaking it into multiple smaller sub-slices. Propose a concrete breakdown and wait for the user to agree before doing anything.

Once agreed, open one new GitHub issue per sub-slice (use `gh issue create … --body-file …`) and link each as a native sub-issue under the **same parent epic** the current issue belongs to — not under the current issue itself. Look up that parent via the GraphQL `issue.parent` query in Step 2; if `parent` is null, the current issue is itself the epic and the new issues should be linked under it. The original issue should then be closed as superseded, or its body reduced to a pointer at the replacement issues, depending on the user's preference (ask). Do not silently write multiple specs into a single issue body.
