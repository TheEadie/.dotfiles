---
name: factory-implement2
description: Simplified story workflow — worktree, implement from the spec (and architecture), /code-review high --fix, then a draft PR
effort: medium
disable-model-invocation: true
---

You coordinate a four-step story workflow: worktree → implement → code review → draft PR. Each work step runs in its own `general-purpose` sub-agent so this orchestrator's context stays clear. Keep only each sub-agent's compact summary; never pull diffs, file contents, or review findings into your own context.

## Step 1 — Identify the issue and create the worktree

Scan the user's request for a GitHub issue reference (a full issue URL or a `#NNN` token). If none is present, stop and ask which issue to work on.

Check the issue has a spec: `~/.claude/scripts/gh-sticky get-id <number> spec` prints a comment id or nothing. If there is no `spec` sticky, stop and tell the user to run `/factory-spec` against the issue first. Also note whether an `architecture` sticky exists (`gh-sticky get-id <number> architecture`).

Fetch just the title (`gh issue view <number> --json title -q .title`) and create the worktree with the `EnterWorktree` tool, using a short kebab-case name derived from the title (e.g. `add-csv-export`), not the issue number. Do this yourself rather than in a sub-agent — `EnterWorktree` switches *this* session's working directory, and the sub-agents you dispatch next inherit it. Do not exit the worktree at the end; leave it for the user.

Proceed without asking the user to confirm.

## Step 2 — Implement

Dispatch a `general-purpose` sub-agent (Agent tool) with this prompt, filling in the placeholders:

> Implement GitHub issue `<issue-url>` in the current git worktree.
>
> 1. Run `pwd` and `git rev-parse --show-toplevel` and work only inside that repo root. Address files by paths relative to it — never edit via an absolute path pointing at another checkout.
> 2. Read the spec: `~/.claude/scripts/gh-sticky get-body <number> spec`. <If an architecture sticky exists:> Read the architecture: `~/.claude/scripts/gh-sticky get-body <number> architecture` — honour its component boundaries and public API contracts.
> 3. Read the root `CLAUDE.md` and the steering / testing docs it indexes for the areas you touch, and follow their conventions.
> 4. Implement every acceptance criterion in the spec. For code with observable behaviour in an area that has a test framework, work test-first — invoke the `tdd` skill if it is available.
> 5. Run the project's build, tests, and linters for the areas you changed and get them passing.
>
> Do NOT commit, push, or open a PR. Do NOT run `/code-review` or any review agents — review is a separate later step.
>
> Reply with ONLY a compact summary: files changed (paths only), acceptance criteria met / not met, build and test status, and any decisions or deviations worth flagging. No code, no diffs.

If the sub-agent reports that it could not implement the story (build broken, acceptance criteria unmet), stop and relay that to the user instead of continuing.

## Step 3 — Code review with auto-fix

Dispatch a `general-purpose` sub-agent with this prompt:

> In the current git worktree, invoke the built-in code review skill via the Skill tool: `{skill: "code-review", args: "high --fix"}`. It reviews the uncommitted diff and applies its fixes to the working tree.
>
> The skill may run forked in the background: if the Skill tool returns a launch receipt ("running in the background"), end your turn and wait for the `<task-notification>` carrying its result — do not poll, do not touch the working tree while it runs, and never guess the findings. If the Skill tool refuses the call (e.g. `disable-model-invocation`), report that and stop — do not substitute your own review.
>
> Once the result arrives, run the project's build and tests for the changed areas to confirm the fixes didn't break anything.
>
> Reply with ONLY a compact summary: number of findings, number fixed, any findings left unfixed (one line each: `file:line — short title`), and build/test status after the fixes.

## Step 4 — Open a draft pull request

Dispatch a `general-purpose` sub-agent with this prompt:

> In the current git worktree, invoke the `pr` skill via the Skill tool with args `draft — closes <issue-url>`, and follow its instructions to commit the work, push the branch, and open the pull request **as a draft** (`gh pr create --draft`). Reference `<issue-url>` in the PR description.
>
> Reply with ONLY the PR URL and the list of commit subjects.

## Step 5 — Hand off

Relay a short summary to the user:
- What was implemented, and any acceptance criteria or deviations the implementer flagged
- Code review: findings found / fixed, and any left unfixed
- Build/test status
- The draft PR URL and the worktree path — the PR is theirs to review and mark ready
