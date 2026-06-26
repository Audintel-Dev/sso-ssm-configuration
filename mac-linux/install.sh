#!/usr/bin/env bash

set -e

# ----------------------------
# SCRIPT DIR (FIXED)
# ----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------
# FUNCTIONS
# ----------------------------
log() {
  echo -e "$1"
}

run_cmd() {
  eval "$1"
}

append_if_not_exists() {
  local LINE="$1"
  local FILE="$2"

  grep -qxF "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
}



log "🚀 Starting Dev Environment Setup..."


# ----------------------------
# Pre-flight checks
# ----------------------------
log "🔍 Running pre-flight checks..."

# ----------------------------
# Install dependencies
# ----------------------------
install_mac() {
  log "🍺 Installing AWS CLI v2 and Session Manager Plugin (Mac)..."

  mkdir -p "$HOME/bin"

  # Session Manager Plugin
  curl -L "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/sessionmanager-bundle.zip" \
    -o "$HOME/sessionmanager-bundle.zip"

  unzip -qo "$HOME/sessionmanager-bundle.zip" -d "$HOME"

  cp "$HOME/sessionmanager-bundle/bin/session-manager-plugin" \
    "$HOME/bin/session-manager-plugin"

  chmod +x "$HOME/bin/session-manager-plugin"

  # Add PATH
  if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
      echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
  fi

  # Cleanup
  rm -rf \
    "$HOME/aws" \
    "$HOME/awscliv2.zip" \
    "$HOME/sessionmanager-bundle" \
    "$HOME/sessionmanager-bundle.zip"

  log "✅ AWS CLI installed: $HOME/bin/aws"
  log "✅ Session Manager Plugin installed: $HOME/bin/session-manager-plugin"
}

install_mac

# ----------------------------
# Install scripts
# ----------------------------
log "📦 Installing custom scripts..."

install_script() {
  local SRC="$SCRIPT_DIR/$1"
  local DEST="$HOME/bin/$(basename "$1")"

  if [ -f "$SRC" ]; then
    run_cmd "cp \"$SRC\" \"$DEST\""
    run_cmd "chmod +x \"$DEST\""
    log "✅ Installed $(basename "$1")"
  else
    log "⚠️ Missing script: $SRC"
  fi
}

install_script "scripts/aws-login"
install_script "scripts/dbpc"
install_script "scripts/linux"
install_script "scripts/rds"

# ----------------------------
# Setup rds-map
# ----------------------------
RDS_MAP_SRC="$SCRIPT_DIR/templates/rds-map"
RDS_MAP_DEST="$HOME/.rds-map"

if [ -f "$RDS_MAP_DEST" ]; then
    log "♻️ Replacing existing ~/.rds-map"
else
    log "✅ Creating ~/.rds-map"
fi

cp -f "$RDS_MAP_SRC" "$RDS_MAP_DEST"

chsh -s $(which zsh)

# ----------------------------
# Shell config
# ----------------------------
SHELL_FILE="$HOME/.zshrc"

append_block() {
    local NAME="$1"
    local FILE="$2"
    local CONTENT="$3"

    if grep -q "# >>> $NAME >>>" "$FILE" 2>/dev/null; then
        echo "$NAME already exists. Skipping."
        return
    fi

    {
        echo
        echo "# >>> $NAME >>>"
        echo "$CONTENT"
        echo "# <<< $NAME <<<"
    } >> "$FILE"
}

# ----------------------------
# Aliases
# ----------------------------
append_block "ALIASES" "$SHELL_FILE" '
alias uat="linux uat"
alias prod="linux prod"
alias dbuat="rds uat"
alias dbprod="rds prod"
'

# ----------------------------
# PATH FIX
# ----------------------------
append_if_not_exists 'export PATH="$HOME/bin:$PATH"' "$SHELL_FILE"

# ----------------------------
# DONE
# ----------------------------
log "Loading aliases..."
exec zsh
log "🎉 Setup Complete!"

