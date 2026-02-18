# Prune Merged Worktrees and Branches

1. Remove worktrees whose branches have been merged into main:
   - List all worktrees with `git worktree list`
   - For each worktree (excluding the main working copy), check if its branch has been merged into `origin/main` using `git branch --merged origin/main`
   - Remove merged worktrees with `git worktree remove <path>`
2. Clean up stale worktree references: `git worktree prune`
3. Delete local branches that have been merged into `origin/main`:
   - `git fetch origin --prune`
   - List merged branches with `git branch --merged origin/main`
   - Delete each merged branch (excluding `main` itself) with `git branch -d <branch>`
4. Report a summary of what was removed
