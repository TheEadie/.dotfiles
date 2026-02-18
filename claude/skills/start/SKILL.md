# Start New Work Skill
1. Ask the user what they'll be working on if not already clear from context
2. Choose a short, descriptive branch name (e.g. `fix-login-bug`, `add-retry-logic`). In the `terraform-github` repo, use underscores instead of hyphens (e.g. `fix_login_bug`, `add_retry_logic`).
3. Fetch the latest changes from the remote repository to ensure your work is based on the most recent code:
   - `git fetch origin`
4. Create a new git worktree in a sibling directory based on the latest main branch (or the relevant base branch for your work):
   - Determine the repo root directory name
   - Path: `<repo>-worktrees/<branch-name>` (sibling to the main repo)
   - Example: `git worktree add ../swords-next-feature-worktrees/fix-login-bug -b fix-login-bug`
5. Change working directory to the new worktree using `cd` in Bash
6. Enter plan mode to explore the codebase and design an implementation approach before making changes
7. When you enter plan mode, pause and ask the user to provide the details of what they want to work on, and any specific requirements or constraints they have in mind. This will help you understand the scope of the task and guide your exploration of the codebase effectively.
8. IMPORTANT: At the very top of your plan, include a "Working Directory" section with the absolute path to the worktree and a note that all work must happen there. This ensures the path survives context compression when transitioning from plan to implementation. Before making any file changes during implementation, verify your working directory with `pwd` and `cd` back to the worktree if needed.
