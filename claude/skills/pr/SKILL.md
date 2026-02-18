# Create PR Skill
1. Stage only files related to the current task (no unrelated lockfile/dependency changes)
2. Create focused, atomic commits with descriptive messages
3. Push to a feature branch and create a PR with a clear description
4. Ensure build and tests pass before pushing
5. Before creating the PR, determine the current repo name from the git remote (e.g., `git remote get-url origin`) and check for a lessons file at `~/lgtm/lessons/**/<repo-name>.md`. If a lessons file exists, read it and review your changes against those lessons. Flag any violations and fix them before proceeding.
