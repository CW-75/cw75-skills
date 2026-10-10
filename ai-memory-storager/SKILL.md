---
name: ai-memory-storager
description: >-
  A skill for AI agents to manage persistent memory using Obsidian vaults with a MEMORY.md Map of Content (MOC). This skill is preloaded at session start to read MEMORY.md for context and updates it after completing requirements or sessions.
---

# ai-memory-storager

## Purpose
- Configure and maintain a `MEMORY.md` file as a Map of Content (MOC).
- Establish bidirectional wikilinks between `MEMORY.md` and the Obsidian vault.
- Read `MEMORY.md` **before** starting a session to get the context of older versions, specs, or previous tasks.
- Update `MEMORY.md` **after** finishing a requirement, feature, or session.
- Track active work and store references to new specs or documents to give AI agents a better knowledge base.

## Core Directives

1. **On Session Start (Read Phase):** 
   - ALWAYS read `MEMORY.md` first to acquire context of the project, previous tasks, specifications, and architecture.
   - If `Graphify` is available, run a query to generate context for the current task (e.g., `graphify --focus [[task-name]] --depth 2`) to understand the relationships without reading every file.
   - Ensure the vault exists based on the configuration logic below.

2. **On Task/Requirement Completion (Update Phase):**
   - Save learned knowledge (specs, decisions, errors, learnings) into the vault structure.
   - Update `MEMORY.md` with wikilinks (`[[page-name]]`) to the new vault sections.
   - Ensure the MOC reflects the current state of progress.

## Initialization Rules
If `MEMORY.md` does not exist when starting a session, initialize it using the following setup logic and variables directly. **Do not create separate script files, config files, or AGENTS.md templates for the user.** Just apply this configuration logic in your actions:

**Setup Logic (Internal to LLM):**
- `VAULT_PATH="./vault"`
- `PROJECT_NAME` (derive from the actual workspace if possible)
- `MEMORY_FILE="./MEMORY.md"`
- `INDEXER_DIR="_indexers"`
- `ARCHIVE_DIR="archive"`

When initializing `MEMORY.md` for the first time, use this exact structure:

```md
# MEMORY - Map of Content
## 📋 Active Work
- [[{{PROJECT_NAME}}]] - Project initialization

## 📁 Projects
- [[_indexers/projects-index|Projects Index]]

## 📝 Notes
- [[notes/|Notes]]

## 🔗 Cross-References
- [[AGENTS.md|Agent Instructions]]
- [[vault/|Vault Root]]

## 📊 Progress Log
- [[PROJECT_LOGFILE.md]|Log file for changes]
```
*(Replace `{{PROJECT_NAME}}` with the actual project name)*

## Commands

### `/ai-memory`
When the user types `/ai-memory` for the first time:
- Analyze the workspace using the current model to determine `PROJECT_NAME`.
- Assign the setup variables internally based on setup parameters (e.g. Vault location, indexer path).
- Set up the directory structure and initialize `MEMORY.md` using the exact structure provided above.
- **Do not** generate a default.conf, install.sh script, or any bash scripts. Manage the memory entirely through your file operations.
- Avoid generating an `AGENTS.md` template file automatically.

## Vault Structure Conventions

When saving notes or capturing knowledge, use this folder structure within `VAULT_PATH`:
```
vault/
├── _indexers/
├── projects/
│   └── project-name/
│       ├── specs/
│       ├── decisions/
│       ├── errors/
│       └── learnings/
├── notes/
├── references/
└── archive/
```

### Wikilink & Persistence Rules (Critical)
- **No Dead Links:** Whenever you add a `[[wikilink]]` to `MEMORY.md` or any other file, **you must physically create the target `.md` file** in the vault. Do not hallucinate links to files that do not exist.
- Use `[[page-name]]` or `[[page-name|display-text]]` for all internal references.
- Folders: `[[folder/note]]` (resolves relative to vault root).
- External files: `/path/to/file.md`
- **NEVER** use standard markdown links like `[text](url)` for vault files.

### YAML Frontmatter & Tagging Schema
Every markdown file created inside the vault MUST contain a YAML frontmatter block for Obsidian Dataview and Graphify compatibility. Use the following hierarchical tagging schema:

```yaml
---
project: {{PROJECT_NAME}}
type: {{spec|decision|error|learning}}
date: {{YYYY-MM-DD}}
tags:
  - #project/{{PROJECT_NAME}}
  - #type/{{spec|decision|error|learning}}
  - #status/{{active|completed|archived}}
---
```
This structured metadata ensures that indexers and context graphs can dynamically query and group related memory fragments efficiently.