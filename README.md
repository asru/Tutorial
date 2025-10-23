# MacroQuest / RedGuides Lua Scripts

This repository uses a folder-per-script structure where each script has its own directory containing an `init.lua` and related files.

Current scripts:
- `vsCodeLua/` - Example script showing the recommended folder structure

## Directory Structure
```
lua/
├── deploy-to-mq.ps1         # Deployment helper
├── README.md               # This file
└── vsCodeLua/             # Example script
    ├── init.lua           # Main entry point
    └── example.lua        # Supporting module
```

## Deployment
Use the PowerShell script to deploy a specific script folder to your RedGuides lua directory:

```powershell
# Deploy a specific script folder
.\deploy-to-mq.ps1 -ScriptDir vsCodeLua

# Or deploy all script folders
.\deploy-to-mq.ps1
```

Target RedGuides path (configured in deploy-to-mq.ps1):
D:\ProgramData\RedGuides\redfetch\Downloads\VanillaMQ_LIVE\lua