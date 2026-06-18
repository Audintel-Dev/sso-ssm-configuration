#!/usr/bin/env zsh

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

if [ ! -f "$RDS_MAP_SRC" ]; then
  log "❌ Expected template not found: $RDS_MAP_SRC"
  log "👉 Script dir: $SCRIPT_DIR"
  log "👉 Current dir: $(pwd)"
  exit 1
fi

if [ ! -f "$RDS_MAP_DEST" ]; then
  cp "$RDS_MAP_SRC" "$RDS_MAP_DEST"
  log "✅ Created ~/.rds-map"
  log "👉 Please update ~/.rds-map with your DB details"
else
  log "ℹ️ ~/.rds-map already exists (skipping)"
fi

# ----------------------------
# Detect shell
# ----------------------------
SHELL_NAME=$(basename "$SHELL")

if [[ "$SHELL_NAME" == "zsh" ]]; then
  SHELL_FILE="$HOME/.zshrc"
else
  SHELL_FILE="$HOME/.bashrc"
fi

log "⚙️ Updating $SHELL_FILE"

touch "$SHELL_FILE"
cp "$SHELL_FILE" "$SHELL_FILE.bak.$(date +%s)"

append_block() {
  local NAME="$1"
  local FILE="$2"
  local CONTENT="$3"

  echo "Appending $NAME to $FILE"

  {
    echo ""
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

# ---------------------------------
# AUTOMATING dbuat dbprod aws-login
# ---------------------------------


# append_block "SSM_SETUP" "$SHELL_FILE" '
# start_ssm_setup() {

#   [ -t 0 ] || return

#   echo ""
#   echo -n "Continue full setup[aws-auth,dbprod,dbuat]? (y/n): "
#   read choice
#   [ "$choice" != "y" ] && echo "Skipping setup..." && return

#   aws_auto_login() {
#   aws sts get-caller-identity --profile uat >/dev/null 2>&1 || aws-login uat
#   aws sts get-caller-identity --profile prod >/dev/null 2>&1 || aws-login prod
#   }
#   aws_auto_login

#   # PROD
#   echo -n "Open PROD DB tunnels? (y/n): "
#   read prodChoice
#   if [ "$prodChoice" = "y" ]; then
#     dbprod
#   fi

#   # UAT
#   echo -n "Open UAT DB tunnels? (y/n): "
#   read uatChoice
#   if [ "$uatChoice" = "y" ]; then
#     dbuat
#   fi
  
#   echo "Setup complete"
# }

# start_ssm_setup
# '



# ----------------------------
# PATH FIX
# ----------------------------
append_if_not_exists 'export PATH="$HOME/bin:$PATH"' "$SHELL_FILE"

source "$SHELL_FILE"

# ----------------------------
# DONE
# ----------------------------
log ""
log "🎉 Setup Complete!"
log ""
log "👉 Reload shell:"
log "   source $SHELL_FILE"
log ""
