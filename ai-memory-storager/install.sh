#!/usr/bin/env bash
# Install ai-memory-storager into a project
# Usage: ./install.sh [project-path]

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-$(pwd)}"

echo "Installing ai-memory-storager to: $PROJECT_DIR"

# Copy scripts
mkdir -p "$PROJECT_DIR/.ai-memory/scripts"
cp "$SKILL_DIR/scripts/ai-memory.sh" "$PROJECT_DIR/.ai-memory/scripts/"
chmod +x "$PROJECT_DIR/.ai-memory/scripts/ai-memory.sh"

# Copy config template
mkdir -p "$PROJECT_DIR/.ai-memory/config"
cp "$SKILL_DIR/config/default.conf" "$PROJECT_DIR/.ai-memory/config/"

# Copy templates
mkdir -p "$PROJECT_DIR/.ai-memory/templates"
cp "$SKILL_DIR/templates/"*.tmpl "$PROJECT_DIR/.ai-memory/templates/" 2>/dev/null || true

# Create wrapper script in project root
cat > "$PROJECT_DIR/ai-memory" <<'WRAPPER'
#!/usr/bin/env bash
# ai-memory-storager wrapper - runs from project root
exec "$(dirname "$0")/.ai-memory/scripts/ai-memory.sh" "$@"
WRAPPER
chmod +x "$PROJECT_DIR/ai-memory"

# Create convenience aliases
cat > "$PROJECT_DIR/.ai-memory/aliases.sh" <<'ALIASES'
# Source this file or add to your shell rc for shortcuts
alias aim="ai-memory"
alias aim-init="ai-memory init-memory"
alias aim-sync="ai-memory sync-memory"
alias aim-checkpoint="ai-memory checkpoint"
alias aim-learn="ai-memory capture-learning"
alias aim-compact="ai-memory compact-vault"
alias aim-link="ai-memory vault-link"
alias aim-index="ai-memory generate-indexers"
alias aim-graph="ai-memory graph-context"
ALIASES

echo "Installation complete!"
echo ""
echo "To use in your project:"
echo "  cd $PROJECT_DIR"
echo "  ./ai-memory init-memory"
echo ""
echo "Or add shortcuts to your shell:"
echo "  source $PROJECT_DIR/.ai-memory/aliases.sh"
echo "  aim-init"
echo ""
echo "The skill files are in: $PROJECT_DIR/.ai-memory/"
echo "Your project config will be at: $PROJECT_DIR/.ai-memory.conf"