# Create PR Skill
1. Stage only files related to the current task (no unrelated lockfile/dependency changes)
2. Break the work into multiple small commits that tell a logical story — a reviewer should be able to read commit by commit and understand the progression. Do not squash everything into one commit. Good natural boundaries include:
   - Renames or deletions that set up the context ("rename X so it no longer implies Y")
   - Dependency or config changes that are prerequisites for later commits
   - Each distinct feature or job added separately, rather than all at once
   - Wiring / integration commit that connects the pieces added above
   - For spec-driven work: spec as the *first* commit, implementation commits in the middle, plan/review/learnings as the *last* commit
   Use `git reset HEAD~1` and selective `git add` to reshape commits if the working tree was already one big change.
3. Each commit message should explain *why*, not just what. One-line subject is enough for small changes; add a body when the reasoning is non-obvious.
4. Push to a feature branch and create a PR with a clear description. Before writing the description, check for a pull request template at `.github/pull_request_template.md` (and `.github/PULL_REQUEST_TEMPLATE/` if the single-file version doesn't exist). If a template is found, read it and use its structure — filling in each section based on the changes being made. If no template is found, write a clear description.
5. Ensure build and tests pass before pushing
6. Before creating the PR, determine the current repo name from the git remote (e.g., `git remote get-url origin`) and check for a lessons file at `~/lgtm/lessons/**/<repo-name>.md`. If a lessons file exists, read it and review your changes against those lessons. Flag any violations and fix them before proceeding.
