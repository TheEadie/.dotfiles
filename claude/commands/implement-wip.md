---
description: Orchestrate planning, implementation, an automated review-fix loop, and interactive resolution of any leftovers for a slice issue
effort: medium
---

You coordinate the full slice workflow: plan → implement → (review ↔ fix)* → resolve. The plan and implement phases run in their own sub-agents (`slice-planner-wip`, `slice-implementer-wip`). The review-fix loop dispatches `reviewer-spec-wip`, `reviewer-security-wip`, `reviewer-csharp-wip`, and `reviewer-react-wip` in parallel, merges their findings inline, then alternates with `slice-fixer-wip` until the slice converges — no Blockers and no Accept-recommended Suggestions remain — or a hard cap is hit. The resolution phase then runs interactively in this session for whatever's left (Nitpicks, Declines, and any auto-fixable findings the cap cut off). Each sub-agent's frontmatter pins the model it runs on.

## Sticky comment operations

Sticky comments are GitHub issue comments identified by a hidden HTML-comment marker on the first line: `<!-- claude:sticky:<name> -->`. Subsequent runs find and update the existing comment by marker.

**Read a sticky:**
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
gh api "repos/$REPO/issues/<number>/comments" --paginate \
  --jq '.[] | select(.body | startswith("<!-- claude:sticky:<name> -->")) | {id, body, url}'
```

**Write (create-or-update) a sticky:**
1. Render the full body to `/tmp/sticky-<name>.md` with the marker as the first line.
2. Look up the existing comment id with the read query above.
3. If found: `gh api -X PATCH "repos/$REPO/issues/comments/<id>" -F body=@/tmp/sticky-<name>.md`
4. Otherwise: `gh issue comment <number> --body-file /tmp/sticky-<name>.md`

Always pass body via `--body-file` / `-F body=@…`, never inline.

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

- Issue body exists (spec) but no `plan` sticky → planning + implementing + review-fix loop + interactive resolution
- `plan` sticky exists but no `learnings` sticky → implementing + review-fix loop + interactive resolution
- `learnings` sticky exists but no `review` sticky → review-fix loop + interactive resolution
- All three stickies exist → only Step 5 (interactive resolution) runs against the existing `review` sticky

If the issue body is empty or still looks like the one-sentence stub created by `/epic`, stop and tell the user to run `/spec` against it first.

Record the issue URL and number as `<issue>` for use below. Present the planned phase list to the user and ask them to confirm before proceeding.

## Step 2 — Plan phase

Skip if the `plan` sticky comment already exists on the issue.

Dispatch the `slice-planner-wip` agent (via the Agent tool with `subagent_type: "slice-planner-wip"`), passing the issue URL/number `<issue>` in the prompt.

After the agent completes, verify the `plan` sticky comment now exists on the issue. If it does not, stop and report the failure to the user.

## Step 3 — Implement phase

Skip if the `learnings` sticky comment already exists on the issue.

Dispatch the `slice-implementer-wip` agent (via the Agent tool with `subagent_type: "slice-implementer-wip"`), passing the issue URL/number `<issue>` in the prompt.

After the agent completes, verify the `learnings` sticky comment now exists on the issue. If it does not, stop and report the failure to the user.

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

Also classify every touched file by **security risk** for the security reviewer:

- **CRITICAL** — auth / session / token code, password handling, crypto, deserialization entry points, anything that runs as a privileged process.
- **HIGH** — request handlers / controllers / API routes, database access layers, file I/O with user-controlled paths, outbound HTTP from server code, redirect endpoints, template rendering with user data, dependency manifests (`*.csproj`, `package.json`, `package-lock.json`, `requirements.txt`, etc.).
- **MEDIUM/LOW** — everything else.

Record the base branch, current branch, C# file list, web file list, component list, and the security-classified file list (CRITICAL/HIGH only — the security reviewer will lightly scan the rest itself) — reuse these in every review iteration without re-running the diff.

### Iteration 1 — initial review

Dispatch reviewer sub-agents in a **single message** (parallel):

1. **Always** spawn `reviewer-spec-wip` (via the Agent tool with `subagent_type: "reviewer-spec-wip"`) with: the GitHub issue URL, the base branch, and the current branch.
2. **Always** spawn `reviewer-security-wip` (via the Agent tool with `subagent_type: "reviewer-security-wip"`) with: the base branch, the current branch, and the security-classified file list (CRITICAL/HIGH).
3. **If any C# files changed**, spawn `reviewer-csharp-wip` (via the Agent tool with `subagent_type: "reviewer-csharp-wip"`) with: the base branch, the current branch, the C# file list, and the component(s).
4. **If any web files changed**, spawn `reviewer-react-wip` (via the Agent tool with `subagent_type: "reviewer-react-wip"`) with: the base branch, the current branch, the web file list, and the web project directory.

After all sub-agents have returned, merge their findings into the `review` sticky comment using the template below. Preserve each sub-agent's findings verbatim within its section — do not rerank across axes. Renumber findings only if needed to keep IDs unique (e.g. `Spec B1`, `Security B1`, `C# B1`, `Web B1` are fine as-is). Write a one-paragraph verdict that summarises all axes honestly: a Spec-pass / Security-fail reads very differently from a Spec-fail / Security-pass.

Render the merged review to `/tmp/sticky-review.md` with `<!-- claude:sticky:review -->` as the first line, then create or update the `review` sticky comment using the write flow above.

Wrap the body content in a single `<details>` block (collapsed by default) so the comment renders as a one-line header on the issue. Keep the sticky marker on line 1 and the `# Review — …` title outside the `<details>`. The blank line between `<summary>` and the first heading is required for GitHub to render the inner markdown. When you later update findings in place during Step 5, preserve the `<details>` / `</details>` wrapper — only the `**Decision:**` lines inside change.

```markdown
<!-- claude:sticky:review -->

# Review

_Generated by Claude Code._

<details>
<summary>Show review</summary>

## Verdict

[One paragraph. Summarise both axes: does the implementation satisfy the spec? Does it follow the standards? Any blockers the user must address before merging?]

## Spec

[Verbatim from reviewer-spec-wip: Acceptance Criteria table, Blockers, Suggestions, Nitpicks. If a sub-section is empty, write "None".]

## Security

[Verbatim from reviewer-security-wip, including the Summary PASS/FAIL line. If a sub-section is empty, write "None".]

## C# Standards

[Verbatim from reviewer-csharp-wip, including the build PASS/FAIL line. Omit this whole section if reviewer-csharp-wip was not dispatched.]

## Web Standards

[Verbatim from reviewer-react-wip, including the lint PASS/FAIL line. Omit this whole section if reviewer-react-wip was not dispatched.]

## Recommended Actions

[For every finding across all axes, state your recommended action and a one-line reason. Reference findings by axis-prefixed ID:]

- **Spec B1** — Accept — [reason]
- **Security B1** — Accept — [reason]
- **C# B1** — Accept — [reason]
- **C# S1** — Decline — [reason]
- **Web N1** — Accept — [reason]

Valid actions: `Accept` or `Decline`. Cover every finding.

</details>
```

Verify the `review` sticky comment now exists. If it does not, stop and report the failure to the user.

### Loop

Repeat the following until either the auto-fixable list is empty or you have completed 3 review iterations:

1. **Read the latest `review` sticky comment** (using the read flow above) and parse its `## Recommended Actions` section.
2. **Collect the auto-fixable findings** — every finding whose severity is `Blocker` or `Suggestion` *and* whose recommendation is `Accept`. **Do not include Nitpicks. Do not include Declines.** These stay for the user in Step 5.
3. If the auto-fixable list is **empty**, exit the loop and proceed to Step 5.
4. If you have already completed **3 review iterations** in total, exit the loop and proceed to Step 5 — note in your hand-off that the cap was hit so the user knows there may still be auto-fixable items left.
5. Dispatch the `slice-fixer-wip` agent (via the Agent tool with `subagent_type: "slice-fixer-wip"`), passing the issue URL/number `<issue>` plus the auto-fixable findings list. Each item should include its ID, severity, file:line, the issue, and the proposed fix — copied verbatim from the relevant section of the `review` sticky comment so `slice-fixer-wip` doesn't have to re-parse it.
6. After `slice-fixer-wip` returns, dispatch the same reviewer sub-agents in parallel (using the recorded base branch, current branch, file lists, component list, and security-classified file list) to produce a fresh review against the updated code. Merge their outputs and update the `review` sticky comment using the same template. This is the next review iteration — increment your counter. Verify the `review` sticky comment has been updated.
7. Go back to step 1.

Briefly tell the user when each iteration begins and ends, including which findings went to `slice-fixer-wip` and what `slice-fixer-wip` reported back (Fixed / Deviated / Skipped). Do not surface the full review body — the user can read the sticky if they want detail.

## Step 5 — Resolve remaining findings interactively

By the time you reach this step, the loop has driven the slice to either zero auto-fixable findings or the iteration cap. Step 5 handles whatever the loop did not auto-resolve: Nitpicks, Declines, and (if the cap was hit) any leftover Accept-recommended Blockers/Suggestions.

Read the latest `review` sticky comment and collect all findings in document order: Blockers (B1, B2, …), then Suggestions (S1, S2, …), then Nitpicks (N1, N2, …). Skip any finding whose `**Decision:**` line is already set to `Accept` or `Decline`.

For each remaining finding, look at the referenced file to make the proposed fix concrete.

Present all findings at once as a single table:

| ID | Severity | Title | File | Issue | Proposed Fix |
|----|----------|-------|------|-------|--------------|
| B1 | Blocker | … | `path/to/file:line` | … | … |
| S1 | Suggestion | … | `path/to/file:line` | … | … |
| N1 | Nitpick | … | `path/to/file:line` | … | … |

Then ask: **"Reply with the IDs you want resolved (e.g. `B1 S2`), the IDs you want ignored, or `all` to resolve everything. Any ID not mentioned will be skipped."**

Wait for a single reply, then apply all accepted fixes in one batch. After all changes are made, update the `review` sticky comment in place:

- Update each accepted finding's `**Decision:**` line to `Accept`.
- Update each declined finding's `**Decision:**` line to `Decline`.
- Leave skipped findings as `*(pending)*`.

To edit in place: read the current body of the `review` sticky comment, apply the line changes, and write the full updated body back to the same comment via the write flow above. Do not append a second `review` sticky.

## Step 6 — Hand off

Tell the user:
- How many review iterations ran and whether the loop converged or hit the 3-iteration cap
- How many findings the loop auto-fixed (and any that `slice-fixer-wip` reported as Deviated or Skipped)
- How many findings Step 5 resolved, ignored, and skipped
- Whether any unresolved Blockers remain (they must be addressed before merging)
- Next step: run `/pr` to create the pull request

Do not commit, push, or open a PR — the user triggers that.
