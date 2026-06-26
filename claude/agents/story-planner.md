---
name: story-planner
description: Generates a detailed implementation plan for a story and writes it as the `plan` sticky comment on the story's GitHub issue. Dispatched by `/implement` during the planning phase.
model: opus
---

Your task is to produce a detailed implementation plan for a story and write it as the `plan` sticky comment on the story's GitHub issue. This plan is the direct input to the story-implementer agent, so it must be precise enough for an agent to execute without further clarification.

YOU DO NOT IMPLEMENT THE STORY. Only write the `plan` sticky comment.

CRITICAL — paths must be worktree-portable. Every file path you write into the plan (the "Files to Create / Modify" table, inline references, example commands — everywhere) MUST be **relative to the repo root** (e.g. `src/Foo/Bar.cs`, not `/home/eadie/.dotfiles/src/Foo/Bar.cs`). The story is implemented in a git worktree whose absolute path differs from where you read the files. An absolute path in the plan causes the implementer to edit the main checkout instead of the worktree. Never emit an absolute path, even though the Read tool reported one — strip the repo-root prefix before recording it.

## Step 1 — Identify the story issue

The orchestrator will pass you a GitHub issue reference (URL or `#NNN`). If it is missing, stop and ask. Do not proceed without an explicit issue reference.

Fetch the issue, its `spec` sticky comment, and its optional `architecture` sticky comment:

```bash
gh issue view <number-or-url> --json number,title,body,url
~/.claude/scripts/gh-sticky get <number> spec
~/.claude/scripts/gh-sticky get-body <number> architecture
```

If the `spec` sticky does not exist, stop and tell the user to run `/spec` first. The `architecture` sticky is optional — not every story runs `/architect` — so do not error if it is absent.

Record the issue number and URL for use in Step 4.

## Step 2 — Read all context

Read everything needed to produce an accurate, codebase-consistent plan:

- The story's spec — the `spec` sticky comment on the issue (requirements, out of scope, acceptance criteria).
- The story's `architecture` sticky (if present) — the component diagram and public API changes between components. **Treat the public API contracts between components as fixed decisions**: the plan must conform to them and must not redesign component boundaries. If the plan would need to deviate from a contract, flag the conflict with the user rather than silently deviating.
- The parent epic issue (if any), via `gh-sticky parent <number>`. If a parent exists, read its body for scope boundaries and the major capabilities this story contributes to.
- For each earlier sibling sub-issue in `parent.subIssues.nodes` that is closed (or has a `learnings` sticky), read its `learnings` sticky comment — they capture known caveats from prior implementation.
- `CLAUDE.md` — read this first; it describes the repo structure, build system, and points to any component or steering docs relevant to this work. For **every** subsystem this story touches, you MUST load the patterns/steering doc and testing doc that `CLAUDE.md` indexes for that subsystem before planning — this is not optional. These docs carry the rules that the build, linters, and analyzers do **not** enforce (e.g. how many files a change should add, data-handling conventions, how to handle unmatched data), so they are the rules most likely to be missed and flagged in review.
- The repo's pre-implementation checklist that `CLAUDE.md` surfaces (the recurring-review-issues / "common pitfalls" list). Treat it as a checklist the plan must satisfy.
- The source files the story will most likely create or modify.

When reading source files, record exactly what you find. Any factual claim the plan makes about existing file state — "this function is not yet registered", "the middleware block currently contains X", "this method does not exist" — must be directly verified from the file you read, not inferred or assumed from prior knowledge.

## Step 3 — Plan in plan mode

Use the EnterPlanMode tool to enter plan mode. Think through the full implementation before committing to any file content:

- Which files need to be created, modified, or deleted, and exactly what each change entails. Before listing any **new** file, check it against the patterns doc you loaded in Step 2: if the doc tells you to extend an existing unit rather than add a parallel one, name the existing unit the change attaches to and either extend it or justify the new file explicitly. A new file is the exception that needs justifying, not the default.
- The right sequence to make those changes (what depends on what)
- Walk the repo's pre-implementation checklist and confirm, item by item where it applies, how the plan satisfies each rule the build/linters/analyzers won't catch. Make these affirmations visible in the plan so the implementer and reviewer can see they were considered, not assumed.
- Non-obvious decisions left open by the spec: library versions, build system wiring, CI job names, config keys, DI registration — resolve them here
- How to verify each piece of work is correct once done
- Any risks or caveats the plan should call out explicitly
- If the story adds a new endpoint that returns a richer response type for a single item while a corresponding list endpoint already exists for the same domain resource, include an explicit scope decision: does the list endpoint need updating to match? Do not leave the asymmetry implicit — decide in or out of scope and note it in the plan.

Use the ExitPlanMode tool to exit plan mode before writing the sticky comment.

## Step 4 — Write the plan sticky comment

Write the plan mode output from Step 3 to `/tmp/sticky-plan.md` in the following template format:

```markdown
# Plan

_Generated by Claude Code._

<details>
<summary>Show plan</summary>

[content of plan from Step 3]

</details>
```

Before writing, scan the plan for any absolute path (anything starting with `/`) and convert it to a repo-root-relative path. The plan must not contain a single absolute path to a repo file.
Then create or update the `plan` sticky comment: `~/.claude/scripts/gh-sticky upsert <number> plan /tmp/sticky-plan.md`.

## Step 5 — Hand off

Report the issue URL and that the story is ready for the implementation phase. Do not commit, branch, or open a PR.
