# Tutorial Script Development Workflow

Quick reference guide for contributing to the EverQuest Tutorial Lua script.

## Repository Links
- **Your Fork**: https://github.com/asru/Tutorial
- **Upstream (Original)**: https://github.com/Rouneq/Tutorial
- **Local Path**: `C:\Users\audun\OneDrive\Documents\GitHub\lua`

---

## Daily Development Workflow

### 1. Make Changes
Edit files in the `MyTutorial/` folder. This is your source of truth.

Main file: `MyTutorial/init.lua`

### 2. Test Your Changes
Deploy to the test location in-game:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy-to-mq.ps1" -ScriptDir MyTutorial -NewName TestTutorial -Force
```

Test the script in EverQuest with your TestTutorial deployment.

### 3. Commit Your Changes
Once you're satisfied with the changes:

```powershell
# Check what files changed
git status

# Stage your changes
git add MyTutorial/

# Commit with a descriptive message
git commit -m "Brief description of what you changed"
```

**Tip**: Write clear commit messages describing WHAT changed and WHY.

### 4. Push to Your Fork
```powershell
git push
```

Your changes are now backed up on GitHub at https://github.com/asru/Tutorial

---

## Contributing Back to the Main Repository

When you have a stable feature or bug fix ready to share:

### Option A: Via GitHub Website (Easiest)
1. Go to https://github.com/asru/Tutorial
2. Click the green "Contribute" button
3. Click "Open pull request"
4. Write a clear description of your changes
5. Click "Create pull request"

### Option B: Via Command Line
```powershell
# Make sure you're up to date with upstream
git fetch upstream
git merge upstream/master

# Push your changes
git push

# Then create PR on GitHub website
```

---

## Syncing with Upstream (Getting Latest Updates)

To get the latest changes from Rouneq's original repository:

```powershell
# Fetch the latest from upstream
git fetch upstream

# Merge into your local master
git merge upstream/master

# Push to your fork
git push
```

---

## Common Git Commands Reference

### Check Status
```powershell
git status                 # See what files have changed
git log --oneline -10      # See last 10 commits
git diff                   # See unstaged changes
```

### Undo Changes
```powershell
git checkout -- filename   # Discard changes to a file (before staging)
git reset HEAD filename    # Unstage a file
git reset --soft HEAD~1    # Undo last commit (keep changes)
```

### View History
```powershell
git log                    # View commit history
git log --graph --oneline  # View as graph
```

### Branch Management (for future features)
```powershell
git branch feature-name    # Create a new branch
git checkout feature-name  # Switch to that branch
git checkout master        # Switch back to master
git merge feature-name     # Merge feature into current branch
```

---

## VS Code Git Integration

You can use VS Code's built-in Git panel instead of terminal commands:

1. **Source Control Panel**: Press `Ctrl+Shift+G`
2. **Stage Changes**: Click `+` next to files
3. **Commit**: Enter message and press `Ctrl+Enter`
4. **Push**: Click the `...` menu → Push
5. **View Changes**: Click on files to see diffs

---

## File Structure

```
lua/
├── MyTutorial/              # Source files (edit these)
│   ├── init.lua            # Main script
│   ├── ext/                # External libraries
│   └── inc/                # Include files
├── vsCodeLua/              # Other Lua scripts
├── deploy-to-mq.ps1        # Deployment script
├── .gitignore              # Files to ignore in Git
├── WORKFLOW.md             # This file
└── README.md               # Project readme
```

**Note**: The `TestTutorial/` folder is excluded from Git (via .gitignore) since it's just a deployment target.

---

## Troubleshooting

### Authentication Issues
If Git asks for credentials again:
```powershell
gh auth status    # Check authentication status
gh auth login     # Re-authenticate if needed
```

### Merge Conflicts
If you get a merge conflict when syncing with upstream:
1. Open the conflicted file in VS Code
2. Use the built-in merge conflict resolver (VS Code highlights conflicts)
3. Choose which changes to keep
4. Save, stage, and commit

### Need Help?
- Git documentation: https://git-scm.com/doc
- GitHub CLI docs: https://cli.github.com/manual/
- VS Code Git guide: https://code.visualstudio.com/docs/sourcecontrol/overview

---

## Quick Checklist Before Contributing

- [ ] Tested changes with deploy-to-mq.ps1
- [ ] Verified in-game with multiple character classes (if applicable)
- [ ] Committed with clear, descriptive message
- [ ] Pushed to your fork
- [ ] Ready to create Pull Request with detailed description

---

*Last Updated: October 23, 2025*
