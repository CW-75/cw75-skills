---
name: dtc-manager
description: >-
  A skill that manages Dynamic Tool Calling (DTC) for agents. It dynamically discovers and adapts to any available skills and tools in the project. It provides strict heuristics to optimize token usage, leverages specific AI tools over broad shell commands, and dynamically maps the best execution plan for any given task.
---

# dtc-manager

## Purpose
- **Dynamic Tool Calling (DTC):** Equip agents to dynamically select and invoke the most specific, efficient tools for a given task.
- **Adaptive Skill Discovery:** Dynamically scan and understand any skill folders or external tools in the project environment to upgrade the agent's workflow on the fly.
- **Cost & Token Optimization:** Enforce strict heuristics to minimize context window bloat and token expenditure during file reading, searching, and writing.
- **File System Mastery:** Seamlessly mix specific AI file tools and native Linux shell tools, preferring the cheapest and most precise option.

## Core Directives

### 1. Adaptive Skill & Tool Discovery
Before initiating a complex task, the agent MUST dynamically map its environment to discover available capabilities.
- **Scan for Skills:** Actively search for skill directories across the workspace (e.g., `./skills`, `.agents/skills`, or global plugin folders).
- **Read Capabilities:** If a discovered skill or tool seems relevant to the task at hand, read its `SKILL.md` or documentation to ingest its purpose.
- **Reuse Over Reinvention:** Always prioritize using an existing discovered skill over writing ad-hoc scripts or relying on generic bash approaches.

### 2. Strict Token Optimization Heuristics
You must strictly guard the token context window. Follow these rules when handling file operations:
- **Search Phase:** Always use the `grep_search` tool (or `rg`/`git grep` via shell) to pinpoint exact filenames and line numbers *before* reading contents. Never blindly read or list entire directories with heavy nesting.
- **Read Phase:** Never use `view_file` on a file without providing `StartLine` and `EndLine` parameters unless the file is verified to be small (under 200 lines). Extract only the necessary context.
- **Write Phase:** Prefer `replace_file_content` or `multi_replace_file_content` for surgical edits. Only use `write_to_file` with `Overwrite: true` when entirely replacing a document.

### 3. File Operation Hierarchy
Always resolve tasks using the most specific tool available in this order of precedence:
1. **Specific AI Tools:** (e.g., `view_file`, `grep_search`, `replace_file_content`). These return structured data and handle chunking safely.
2. **Read-Only Shell Utilities:** (e.g., `rg`, `find`, `awk`). Use these for advanced parsing or filtering that native tools cannot do concisely.
3. **Write Shell Utilities:** (e.g., `sed`, custom bash scripts). Use only when multi-file structural refactors cannot be cleanly handled by the AI's native file edit tools.

## Commands

### `/dtc-optimize`
When the user types `/dtc-optimize` alongside a task, immediately switch to a planning phase without executing the task.

**Execution Steps:**
1. Dynamically scan the workspace for relevant skills and tools.
2. Evaluate the requirements of the user's task.
3. Output a structured execution plan using the exact template below.

**Required Output Template:**
```markdown
### 🛠️ DTC Execution Plan

**Objective:** [Brief 1-sentence description of the task]

**Discovered & Selected Skills:** 
- `[Skill Name]`: [Why it is being used for this task]

**Tool Strategy & Token Optimization:** 
1. **[Step 1 Name]** 
   - **Tool:** `[Tool Name / Command]` 
   - **Reasoning:** [Why this is the most token-efficient and precise choice]
2. **[Step 2 Name]** 
   - **Tool:** `[Tool Name / Command]` 
   - **Reasoning:** [Why this is the most token-efficient and precise choice]
```

## Execution Rules
- **Context Preservation:** When pivoting between tools, carry over exact paths and line numbers to avoid duplicate searches.
- **Continuous Adaptation:** If a selected tool or skill fails, or returns too large a payload, immediately pivot to a fallback tool (e.g., if a file is too big for native file viewers, fallback to `sed -n 'X,Yp'`).

### Optional Integrations (Bridge Rules)
- **If `ai-memory-storager` is present in the project:** When planning via `/dtc-optimize` or executing a task, if new architectural patterns or persistent rules are discovered, ensure they are flagged to be documented via the memory system at the end of the task.
