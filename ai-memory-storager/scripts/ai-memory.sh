#!/usr/bin/env bash
# ai-memory-storager - Persistent memory management for AI agents using Obsidian vaults
# Usage: ai-memory.sh <command> [args...]
#
# Commands:
#   init-memory           Initialize memory system in current project
#   sync-memory           Synchronize memory state (read AGENTS.md, update MEMORY.md, Graphify)
#   checkpoint            Save current work progress
#   capture-learning      Save learned knowledge from completed requirement/feature
#   compact-vault         Archive completed work
#   vault-link            Create a wikilink entry in MEMORY.md
#   generate-indexers     Regenerate indexer files in _indexers/
#   graph-context         Generate Graphify context graph for current task
#   help                  Show this help

set -euo pipefail

# --- Configuration Loading ---
CONFIG_FILE=".ai-memory.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
DEFAULT_CONFIG="$SKILL_DIR/config/default.conf"
TEMPLATE_DIR="$SKILL_DIR/templates"

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    elif [[ -f "$DEFAULT_CONFIG" ]]; then
        source "$DEFAULT_CONFIG"
    else
        echo "Error: No configuration found. Run 'init-memory' first." >&2
        exit 1
    fi

    # Set defaults if not in config
    VAULT_PATH="${VAULT_PATH:-./vault}"
    MEMORY_FILE="${MEMORY_FILE:-./MEMORY.md}"
    AGENTS_FILE="${AGENTS_FILE:-./AGENTS.md}"
    GRAPHIFY_ENABLED="${GRAPHIFY_ENABLED:-true}"
    GRAPHIFY_CMD="${GRAPHIFY_CMD:-graphify}"
    INDEXER_DIR="${INDEXER_DIR:-_indexers}"
    AUTO_REGENERATE_INDEXERS="${AUTO_REGENERATE_INDEXERS:-true}"
    COMPACTION_ENABLED="${COMPACTION_ENABLED:-true}"
    ARCHIVE_DIR="${ARCHIVE_DIR:-archive}"
    GIT_AUTO_STAGE="${GIT_AUTO_STAGE:-true}"
    PROJECT_NAME="${PROJECT_NAME:-$(basename "$(pwd)")}"
}

# --- Utility Functions ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
error() { log "ERROR: $*"; exit 1; }
warn() { log "WARN: $*"; }

require_file() {
    [[ -f "$1" ]] || error "Required file not found: $1"
}

require_dir() {
    [[ -d "$1" ]] || error "Required directory not found: $1"
}

ensure_dir() {
    mkdir -p "$1"
}

# Wikilink helpers
wikilink() { echo "[[$1]]"; }
wikilink_alias() { echo "[[$1|$2]]"; }

# Get current task from AGENTS.md
get_current_task() {
    require_file "$AGENTS_FILE"
    grep -E '^Current Task:' "$AGENTS_FILE" | sed -E 's/^Current Task: *//' | head -1
}

# Get vault path relative to project root
vault_abs() { echo "$(pwd)/$VAULT_PATH"; }
memory_abs() { echo "$(pwd)/$MEMORY_FILE"; }
agents_abs() { echo "$(pwd)/$AGENTS_FILE"; }

# --- Command: init-memory ---
cmd_init_memory() {
    log "Initializing ai-memory-storager in $(pwd)"

    # Create config file from template
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cp "$DEFAULT_CONFIG" "$CONFIG_FILE"
        local fallback_project_name
        fallback_project_name="$(basename "$(pwd)")"
        # Update PROJECT_NAME in config
        sed -i "s/PROJECT_NAME=.*/PROJECT_NAME=\"${PROJECT_NAME:-$fallback_project_name}\"/" "$CONFIG_FILE"
        log "Created $CONFIG_FILE"
    fi

    load_config

    # Create vault structure
    ensure_dir "$VAULT_PATH"
    ensure_dir "$VAULT_PATH/$INDEXER_DIR"
    ensure_dir "$VAULT_PATH/projects"
    ensure_dir "$VAULT_PATH/notes"
    ensure_dir "$VAULT_PATH/references"
    ensure_dir "$VAULT_PATH/archive"

    # Create project folder structure
    ensure_dir "$VAULT_PATH/projects/$PROJECT_NAME/specs"
    ensure_dir "$VAULT_PATH/projects/$PROJECT_NAME/decisions"
    ensure_dir "$VAULT_PATH/projects/$PROJECT_NAME/errors"
    ensure_dir "$VAULT_PATH/projects/$PROJECT_NAME/learnings"

    # Initialize Obsidian configuration
    ensure_dir "$VAULT_PATH/.obsidian"
    if [[ ! -f "$VAULT_PATH/.obsidian/app.json" ]]; then
        cat > "$VAULT_PATH/.obsidian/app.json" <<EOF
{
  "useMarkdownLinks": false,
  "newFileLocation": "root",
  "newLinkFormat": "shortest"
}
EOF
        log "Created Obsidian configuration in $VAULT_PATH/.obsidian/"
    fi

    # Create empty indexer files
    for indexer in projects decisions errors specs learnings; do
        touch "$VAULT_PATH/$INDEXER_DIR/${indexer}-index.md"
    done

    # Create MEMORY.md from template
    if [[ ! -f "$MEMORY_FILE" ]]; then
        if [[ -f "$TEMPLATE_DIR/MEMORY.md.tmpl" ]]; then
            sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
                -e "s/{{DATE}}/$(date '+%Y-%m-%d')/g" \
                "$TEMPLATE_DIR/MEMORY.md.tmpl" > "$MEMORY_FILE"
        else
            # Fallback inline template
            cat > "$MEMORY_FILE" <<EOF
# MEMORY - Map of Content

## 📋 Active Work
- [[$PROJECT_NAME]] - Project initialization

## 📁 Projects
- [[_indexers/projects-index|Projects Index]]

## 📝 Notes
- [[notes/|Notes]]

## 🔗 Cross-References
- [[AGENTS.md|Agent Instructions]]
- [[vault/|Vault Root]]

## 📊 Progress Log
- $(date '+%Y-%m-%d'): Memory system initialized
EOF
        fi
        log "Created $MEMORY_FILE"
    fi

    # Create AGENTS.md from template
    if [[ ! -f "$AGENTS_FILE" ]]; then
        if [[ -f "$TEMPLATE_DIR/AGENTS.md.tmpl" ]]; then
            sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
                -e "s/{{VAULT_PATH}}/${VAULT_PATH//\//\\/}/g" \
                -e "s/{{MEMORY_FILE}}/${MEMORY_FILE//\//\\/}/g" \
                -e "s/{{DATE}}/$(date '+%Y-%m-%d')/g" \
                "$TEMPLATE_DIR/AGENTS.md.tmpl" > "$AGENTS_FILE"
        else
            # Fallback inline template
            cat > "$AGENTS_FILE" <<EOF
# AGENTS.md - Agent Instructions & Progress Tracking

## Project
- Name: $PROJECT_NAME
- Vault: $VAULT_PATH
- Memory: $MEMORY_FILE

## Current Task
Current Task: [[$PROJECT_NAME-setup]]

## Memory Checkpoint
Last Sync: [[MEMORY.md#progress-log|Progress Log]]

## Vault Structure
- Projects: $VAULT_PATH/projects/
- Indexers: $VAULT_PATH/_indexers/
- Archive: $VAULT_PATH/archive/
EOF
        fi
        log "Created $AGENTS_FILE"
    fi

    # Initialize Graphify if enabled
    if [[ "$GRAPHIFY_ENABLED" == "true" ]]; then
        if command -v "$GRAPHIFY_CMD" >/dev/null 2>&1; then
            (cd "$VAULT_PATH" && "$GRAPHIFY_CMD" --init 2>/dev/null || true)
            log "Graphify initialized"
        else
            warn "Graphify command '$GRAPHIFY_CMD' not found. Skipping initialization."
        fi
    fi

    # Stage for git if enabled
    if [[ "$GIT_AUTO_STAGE" == "true" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$CONFIG_FILE" "$MEMORY_FILE" "$AGENTS_FILE" "$VAULT_PATH" 2>/dev/null || true
        log "Staged initial files for git"
    fi

    log "Initialization complete. Next: run 'sync-memory' to synchronize."
}

# --- Command: sync-memory ---
cmd_sync_memory() {
    load_config
    require_file "$AGENTS_FILE"
    require_file "$MEMORY_FILE"
    require_dir "$VAULT_PATH"

    log "Synchronizing memory state..."

    # Read current task from AGENTS.md
    local current_task
    current_task=$(get_current_task)
    log "Current task: ${current_task:-none}"

    # Update progress log in MEMORY.md
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="- $timestamp: Sync - Task: ${current_task:-none}"
    
    # Append to progress log (after ## 📊 Progress Log)
    if grep -q '^## 📊 Progress Log' "$MEMORY_FILE"; then
        sed -i "/^## 📊 Progress Log/a\\$log_entry" "$MEMORY_FILE"
    else
        echo -e "\n## 📊 Progress Log\n$log_entry" >> "$MEMORY_FILE"
    fi

    # Regenerate indexers
    if [[ "$AUTO_REGENERATE_INDEXERS" == "true" ]]; then
        cmd_generate_indexers
    fi

    # Incremental Graphify update
    if [[ "$GRAPHIFY_ENABLED" == "true" ]] && command -v "$GRAPHIFY_CMD" >/dev/null 2>&1; then
        log "Running incremental Graphify update..."
        (cd "$VAULT_PATH" && "$GRAPHIFY_CMD" --incremental 2>/dev/null || true)
        
        # Generate context graph for current task
        if [[ -n "$current_task" ]]; then
            cmd_graph_context "$current_task"
        fi
    fi

    # Update AGENTS.md last sync
    sed -i "s@^Last Sync:.*@Last Sync: [[MEMORY.md#progress-log|Progress Log]]@" "$AGENTS_FILE"

    # Stage for git
    if [[ "$GIT_AUTO_STAGE" == "true" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$MEMORY_FILE" "$AGENTS_FILE" "$VAULT_PATH/$INDEXER_DIR" 2>/dev/null || true
    fi

    log "Sync complete"
}

# --- Command: checkpoint ---
cmd_checkpoint() {
    load_config
    require_file "$AGENTS_FILE"
    require_file "$MEMORY_FILE"

    log "Creating checkpoint..."

    local current_task
    current_task=$(get_current_task)
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="- $timestamp: Checkpoint - Task: ${current_task:-none}"

    # Append to progress log
    if grep -q '^## 📊 Progress Log' "$MEMORY_FILE"; then
        sed -i "/^## 📊 Progress Log/a\\$log_entry" "$MEMORY_FILE"
    else
        echo -e "\n## 📊 Progress Log\n$log_entry" >> "$MEMORY_FILE"
    fi

    # Update AGENTS.md
    if [[ -n "$current_task" ]]; then
        sed -i "s@^Current Task:.*@Current Task: $(wikilink "$current_task")@" "$AGENTS_FILE"
    fi
    sed -i "s@^Last Sync:.*@Last Sync: [[MEMORY.md#progress-log|Progress Log]]@" "$AGENTS_FILE"

    # Stage for git
    if [[ "$GIT_AUTO_STAGE" == "true" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$MEMORY_FILE" "$AGENTS_FILE" "$VAULT_PATH" 2>/dev/null || true
        log "Changes staged for git"
    fi

    log "Checkpoint saved"
}

# --- Command: capture-learning ---
cmd_capture_learning() {
    local project="${1:-$PROJECT_NAME}"
    local type="${2:-}"
    local title="${3:-}"
    local content="${4:-}"

    if [[ -z "$type" || -z "$title" ]]; then
        error "Usage: capture-learning <project> <type> <title> [content]"
        error "Types: spec, decision, error, learning"
    fi

    # Validate type
    case "$type" in
        spec|decision|error|learning) ;;
        *) error "Invalid type: $type. Must be: spec, decision, error, learning" ;;
    esac

    load_config
    require_dir "$VAULT_PATH"

    # Sanitize title for filename
    local filename
    filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    local date_prefix
    date_prefix=$(date '+%Y-%m-%d')
    local filepath="$VAULT_PATH/projects/$project/$type/${date_prefix}-${filename}.md"

    ensure_dir "$(dirname "$filepath")"

    # Create note with frontmatter
    cat > "$filepath" <<EOF
---
project: $project
type: $type
title: $title
date: $(date '+%Y-%m-%d')
tags:
  - #$TAG_PROJECT_PREFIX/$project
  - #$TAG_TYPE_PREFIX/$type
  - #$TAG_STATUS_PREFIX/active
---

# $title

$content

## Context
- Project: [[projects/$project|$project]]
- Type: $type
- Captured: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    log "Created learning note: $filepath"

    # Update MEMORY.md project section
    local wikilink_entry="    - $(wikilink_alias "projects/$project/$type/${date_prefix}-${filename}" "$title")"
    
    # Find project section and add entry
    if grep -q "\[\[projects/$project|" "$MEMORY_FILE"; then
        # Project exists, add under it
        sed -i "/\[\[projects\/$project|/a\\$wikilink_entry" "$MEMORY_FILE"
    else
        # Add new project entry
        sed -i "/^## 📁 Projects/a\\- $(wikilink_alias "projects/$project" "$project")\n$wikilink_entry" "$MEMORY_FILE"
    fi

    # Regenerate indexer for this type
    if [[ "$AUTO_REGENERATE_INDEXERS" == "true" ]]; then
        cmd_generate_indexers "$type"
    fi

    # Incremental Graphify
    if [[ "$GRAPHIFY_ENABLED" == "true" ]] && command -v "$GRAPHIFY_CMD" >/dev/null 2>&1; then
        (cd "$VAULT_PATH" && "$GRAPHIFY_CMD" --incremental 2>/dev/null || true)
    fi

    # Stage for git
    if [[ "$GIT_AUTO_STAGE" == "true" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$filepath" "$MEMORY_FILE" "$VAULT_PATH/$INDEXER_DIR/${type}-index.md" 2>/dev/null || true
    fi

    log "Learning captured and indexed"
}

# --- Command: compact-vault ---
cmd_compact_vault() {
    local month="${1:-$(date '+%Y-%m')}"

    load_config
    require_dir "$VAULT_PATH"

    log "Compacting vault for month: $month"

    local archive_path="$VAULT_PATH/$ARCHIVE_DIR/${month}-${PROJECT_NAME}"
    ensure_dir "$archive_path"

    # Find completed projects (status:completed in frontmatter or folder)
    # For now, archive projects that have a completed marker
    for project_dir in "$VAULT_PATH/projects"/*; do
        [[ -d "$project_dir" ]] || continue
        local project_name
        project_name=$(basename "$project_dir")
        
        # Check if project has completion marker
        if [[ -f "$project_dir/.completed" ]] || grep -r "status: completed" "$project_dir" >/dev/null 2>&1; then
            log "Archiving project: $project_name"
            mv "$project_dir" "$archive_path/"
        fi
    done

    # Update MEMORY.md to link archive indexer
    local archive_link="  - $(wikilink_alias "archive/${month}-${PROJECT_NAME}" "Archive: $month")"
    if grep -q "## 📁 Projects" "$MEMORY_FILE"; then
        sed -i "/^## 📁 Projects/a\\$archive_link" "$MEMORY_FILE"
    fi

    # Rebuild Graphify
    if [[ "$GRAPHIFY_ENABLED" == "true" ]] && command -v "$GRAPHIFY_CMD" >/dev/null 2>&1; then
        log "Rebuilding Graphify index..."
        (cd "$VAULT_PATH" && "$GRAPHIFY_CMD" --rebuild 2>/dev/null || true)
    fi

    # Regenerate indexers
    if [[ "$AUTO_REGENERATE_INDEXERS" == "true" ]]; then
        cmd_generate_indexers
    fi

    # Stage for git
    if [[ "$GIT_AUTO_STAGE" == "true" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$MEMORY_FILE" "$VAULT_PATH" 2>/dev/null || true
    fi

    log "Compaction complete. Archived to: $archive_path"
}

# --- Command: vault-link ---
cmd_vault_link() {
    local target="${1:-}"
    local alias="${2:-}"

    if [[ -z "$target" ]]; then
        error "Usage: vault-link <target> [alias]"
    fi

    load_config
    require_file "$MEMORY_FILE"

    # Determine section based on target path
    local section="Notes"
    if [[ "$target" == projects/* ]]; then
        section="Projects"
    elif [[ "$target" == _indexers/* ]]; then
        section="Cross-References"
    fi

    local link_entry
    if [[ -n "$alias" ]]; then
        link_entry="- $(wikilink_alias "$target" "$alias")"
    else
        link_entry="- $(wikilink "$target")"
    fi

    # Add to appropriate section
    sed -i "/^## 📁 $section/a\\$link_entry" "$MEMORY_FILE"

    # Create target file if it doesn't exist
    local target_path="$VAULT_PATH/$target.md"
    if [[ ! -f "$target_path" ]]; then
        ensure_dir "$(dirname "$target_path")"
        cat > "$target_path" <<EOF
---
tags:
  - #$TAG_TYPE_PREFIX/reference
  - #$TAG_STATUS_PREFIX/active
---

# ${alias:-$(basename "$target")}

Created via vault-link on $(date '+%Y-%m-%d %H:%M:%S')
EOF
        log "Created target file: $target_path"
    fi

    # Stage for git
    if [[ "$GIT_AUTO_STAGE" == "true" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
        git add "$MEMORY_FILE" "$target_path" 2>/dev/null || true
    fi

    log "Vault link added to MEMORY.md [$section]"
}

# --- Command: generate-indexers ---
cmd_generate_indexers() {
    local type_filter="${1:-}"

    load_config
    require_dir "$VAULT_PATH"

    local indexer_dir="$VAULT_PATH/$INDEXER_DIR"
    ensure_dir "$indexer_dir"

    local types=("projects" "decisions" "errors" "specs" "learnings")
    if [[ -n "$type_filter" ]]; then
        types=("$type_filter")
    fi

    for type in "${types[@]}"; do
        local indexer_file="$indexer_dir/${type}-index.md"
        log "Generating indexer: $indexer_file"

        cat > "$indexer_file" <<EOF
---
tags:
  - #indexer
  - #$TAG_TYPE_PREFIX/$type
---

# ${type^} Index

Auto-generated on $(date '+%Y-%m-%d %H:%M:%S')

EOF

        # Find all notes of this type
        if [[ "$type" == "projects" ]]; then
            find "$VAULT_PATH/projects" -mindepth 1 -maxdepth 1 -type d | sort | while read -r dir; do
                local name
                name=$(basename "$dir")
                echo "- $(wikilink_alias "projects/$name" "$name")" >> "$indexer_file"
            done
        else
            find "$VAULT_PATH/projects" -path "*/$type/*.md" -type f | sort | while read -r file; do
                local rel_path
                rel_path="${file#$VAULT_PATH/}"
                rel_path="${rel_path%.md}"
                local title
                title=$(grep '^title:' "$file" | sed 's/^title: *//' | head -1)
                title="${title:-$(basename "$file" .md)}"
                echo "- $(wikilink_alias "$rel_path" "$title")" >> "$indexer_file"
            done
        fi
    done

    log "Indexers regenerated"
}

# --- Command: graph-context ---
cmd_graph_context() {
    local focus="${1:-}"

    load_config

    if [[ "$GRAPHIFY_ENABLED" != "true" ]] || ! command -v "$GRAPHIFY_CMD" >/dev/null 2>&1; then
        warn "Graphify not available"
        return 0
    fi

    if [[ -z "$focus" ]]; then
        focus=$(get_current_task)
    fi

    if [[ -z "$focus" ]]; then
        warn "No focus task specified or found in AGENTS.md"
        return 0
    fi

    log "Generating context graph for: $focus"
    
    local output_file="context-graph-$(date '+%Y%m%d-%H%M%S').json"
    (cd "$VAULT_PATH" && "$GRAPHIFY_CMD" --focus "$(wikilink "$focus")" --depth 3 --format json --output "$output_file" 2>/dev/null || true)
    
    if [[ -f "$VAULT_PATH/$output_file" ]]; then
        log "Context graph saved to: $VAULT_PATH/$output_file"
        # Also copy to project root for easy access
        cp "$VAULT_PATH/$output_file" "./$output_file" 2>/dev/null || true
    fi
}

# --- Command: help ---
cmd_help() {
    cat <<'EOF'
ai-memory-storager - Persistent memory management for AI agents using Obsidian vaults

USAGE:
    ai-memory.sh <command> [args...]

COMMANDS:
    init-memory                   Initialize memory system in current project
    sync-memory                   Synchronize memory state
    checkpoint                    Save current work progress
    capture-learning <project> <type> <title> [content]
                                  Save learned knowledge (type: spec|decision|error|learning)
    compact-vault [YYYY-MM]       Archive completed work (default: current month)
    vault-link <target> [alias]   Create wikilink entry in MEMORY.md
    generate-indexers [type]      Regenerate indexer files (type: projects|decisions|errors|specs|learnings)
    graph-context [task]          Generate Graphify context graph for task
    help                          Show this help

CONFIGURATION:
    Copy config/default.conf to project root as .ai-memory.conf and customize.
    Key settings: VAULT_PATH, PROJECT_NAME, GRAPHIFY_CMD, GIT_AUTO_STAGE

EXAMPLES:
    ai-memory.sh init-memory
    ai-memory.sh sync-memory
    ai-memory.sh capture-learning my-project decision "Auth Strategy" "Use JWT with refresh tokens..."
    ai-memory.sh checkpoint
    ai-memory.sh compact-vault 2026-01
    ai-memory.sh vault-link "projects/new-feature" "New Feature"

WIKILINK CONVENTIONS:
    - Internal: [[page-name]] or [[page-name|display]]
    - Folders: [[folder/note]]
    - External: /path/to/file.md
    - NEVER: [text](url)

EOF
}

# --- Main ---
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init-memory) cmd_init_memory "$@" ;;
        sync-memory) cmd_sync_memory "$@" ;;
        checkpoint) cmd_checkpoint "$@" ;;
        capture-learning) cmd_capture_learning "$@" ;;
        compact-vault) cmd_compact_vault "$@" ;;
        vault-link) cmd_vault_link "$@" ;;
        generate-indexers) cmd_generate_indexers "$@" ;;
        graph-context) cmd_graph_context "$@" ;;
        help|--help|-h) cmd_help ;;
        *) error "Unknown command: $cmd. Run 'ai-memory.sh help' for usage." ;;
    esac
}

main "$@"