# AGENTS.md - Agent Instructions & Progress Tracking

## Project
- Name: test-ai-memory
- Vault: ./vault
- Memory: ./MEMORY.md
- Created: 2026-10-02

## Current Task
Current Task: [[[[test-ai-memory-setup]]]]

## Memory Checkpoint
Last Sync: [[MEMORY.md#progress-log|Progress Log]]

## Vault Structure
- Projects: ./vault/projects/
- Indexers: ./vault/_indexers/
- Archive: ./vault/archive/

## Instructions for AI Agents
1. **Session Start**: Run `ai-memory sync-memory` to load context
2. **Read First**: Always read AGENTS.md and MEMORY.md before starting work
3. **Wikilinks Only**: Use `[[page-name]]` or `[[page-name|display]]` for all internal references
4. **No Markdown Links**: NEVER use `[text](url)` syntax
5. **External References**: Use classic pointers `/path/to/file.md`
6. **Task Completion**: Run `ai-memory capture-learning` for specs/decisions/errors/learnings
7. **Session End**: Run `ai-memory checkpoint` to save progress
8. **Periodic**: Run `ai-memory compact-vault` monthly to archive completed work

## Tagging Convention
- Project: `#project/test-ai-memory`
- Domain: `#domain/backend|frontend|infra|docs`
- Type: `#type/spec|decision|error|learning`
- Status: `#status/active|completed|archived`

## Graphify Context
- Current task graph: `ai-memory graph-context`
- Active items: `graphify --tag active --format json`
- Project graph: `graphify --tag project/test-ai-memory`

## Quick Commands
```bash
ai-memory sync-memory        # Load context
ai-memory capture-learning <project> <type> <title> "content"
ai-memory checkpoint         # Save progress
ai-memory compact-vault      # Archive (monthly)
```