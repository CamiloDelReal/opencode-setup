#!/usr/bin/env bash
#
# OpenCode setup for macOS.
#
# Installs opencode from your choice of source, optionally adds plugins and MCP
# servers (ponytail to start), and can remove an existing install completely.
#
# Usage:  ./install.sh [--no-color] [-h|--help]

set -uo pipefail

SCRIPT_NAME=$(basename "$0")

# ---------------------------------------------------------------------------
# Appearance
# ---------------------------------------------------------------------------

USE_COLOR=1
[ -t 1 ] || USE_COLOR=0
[ -n "${NO_COLOR:-}" ] && USE_COLOR=0

setup_colors() {
  if [ "$USE_COLOR" -eq 1 ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; UNDER=$'\033[4m'; RESET=$'\033[0m'
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'; GREY=$'\033[90m'
  else
    BOLD=''; DIM=''; UNDER=''; RESET=''
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; GREY=''
  fi
}

banner() {
  printf '\n'
  printf '  %s%s┌──────────────────────────────────────────────┐%s\n' "$BOLD" "$MAGENTA" "$RESET"
  printf '  %s%s│%s  %sOpenCode%s %ssetup for macOS%s                    %s%s│%s\n' \
    "$BOLD" "$MAGENTA" "$RESET" "$BOLD" "$RESET" "$DIM" "$RESET" "$BOLD" "$MAGENTA" "$RESET"
  printf '  %s%s└──────────────────────────────────────────────┘%s\n' "$BOLD" "$MAGENTA" "$RESET"
  printf '\n'
}

# Section heading.
title() {
  printf '\n  %s%s%s%s\n' "$BOLD" "$UNDER" "$1" "$RESET"
  [ $# -gt 1 ] && printf '  %s%s%s\n' "$DIM" "$2" "$RESET"
  printf '\n'
}

info()  { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
step()  { printf '  %s▸%s %s\n' "$BLUE" "$RESET" "$1"; }
ok()    { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$1"; }
warn()  { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail()  { printf '  %s✘%s %s\n' "$RED" "$RESET" "$1"; }
note()  { printf '    %s%s%s\n' "$GREY" "$1" "$RESET"; }
# Path in one column, what it holds in the next.
note_path() {
  local width=$((${#HOME} + 22))
  printf '    %s%-*s  %s%s\n' "$GREY" "$width" "$1" "$2" "$RESET"
}
blank() { printf '\n'; }

die() { blank; fail "$1"; blank; exit 1; }

# Echo a command dimmed, then run it.
run() {
  printf '    %s$ %s%s\n' "$GREY" "$*" "$RESET"
  "$@"
}

# Same, but hide output unless it fails.
run_quiet() {
  local out
  printf '    %s$ %s%s\n' "$GREY" "$*" "$RESET"
  if ! out=$("$@" 2>&1); then
    printf '%s\n' "$out" | sed 's/^/      /'
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

# confirm "Question?" [y|n]  -> returns 0 for yes
confirm() {
  local prompt="$1" default="${2:-n}" hint reply
  if [ "$default" = "y" ]; then hint="Y/n"; else hint="y/N"; fi
  while true; do
    printf '  %s?%s %s %s[%s]%s ' "$CYAN" "$RESET" "$prompt" "$DIM" "$hint" "$RESET"
    { read -r reply </dev/tty; } 2>/dev/null || reply=""
    reply=$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')
    [ -z "$reply" ] && reply="$default"
    case "$reply" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     note "Please answer y or n." ;;
    esac
  done
}

# menu "prompt" default_index "label|description" ...
# Result in MENU_CHOICE (1-based).
MENU_CHOICE=""
menu() {
  local prompt="$1" default="$2"; shift 2
  local items=("$@") i label desc reply

  i=1
  for entry in "${items[@]}"; do
    label="${entry%%|*}"
    desc="${entry#*|}"
    [ "$desc" = "$entry" ] && desc=""
    if [ "$i" -eq "$default" ]; then
      printf '   %s%s%d%s  %s%s%s %s(default)%s\n' "$BOLD" "$CYAN" "$i" "$RESET" "$BOLD" "$label" "$RESET" "$DIM" "$RESET"
    else
      printf '   %s%d%s  %s\n' "$CYAN" "$i" "$RESET" "$label"
    fi
    [ -n "$desc" ] && printf '      %s%s%s\n' "$GREY" "$desc" "$RESET"
    i=$((i + 1))
  done
  blank

  while true; do
    printf '  %s?%s %s %s[1-%d, enter=%d]%s ' \
      "$CYAN" "$RESET" "$prompt" "$DIM" "${#items[@]}" "$default" "$RESET"
    { read -r reply </dev/tty; } 2>/dev/null || reply=""
    [ -z "$reply" ] && reply="$default"
    case "$reply" in
      ''|*[!0-9]*) note "Enter a number between 1 and ${#items[@]}." ;;
      *)
        if [ "$reply" -ge 1 ] && [ "$reply" -le "${#items[@]}" ]; then
          MENU_CHOICE="$reply"
          return 0
        fi
        note "Enter a number between 1 and ${#items[@]}."
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Add-on registry
#
# To add another add-on, append one entry to each of the five arrays below.
# KIND is free text shown as a tag (plugin, mcp, skill...). DEFAULT is 1 to
# pre-select it. Then add a matching `install_addon_<id>` function.
# ---------------------------------------------------------------------------

ADDON_ID=()
ADDON_NAME=()
ADDON_KIND=()
ADDON_DESC=()
ADDON_DEFAULT=()

ADDON_ID+=("ponytail")
ADDON_NAME+=("ponytail")
ADDON_KIND+=("plugin")
ADDON_DESC+=("Ruleset that stops the agent over-building. Reuse before rewriting, stdlib and native features before dependencies, never cutting validation or security. Adds the /ponytail commands.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("kotlin_vscode")
ADDON_NAME+=("Kotlin by JetBrains")
ADDON_KIND+=("vscode")
ADDON_DESC+=("JetBrains' official Kotlin language server as a VS Code extension. IntelliJ-powered completion, diagnostics, navigation, and rename, so you read Kotlin through the same engine the agent does. Apache 2.0, no subscription.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("serena")
ADDON_NAME+=("Serena")
ADDON_KIND+=("mcp")
ADDON_DESC+=("Symbol-level code navigation and editing over JetBrains' Kotlin LSP. Lets the agent find and edit by symbol instead of reading whole files. Needs uv and JDK 21+.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("context7")
ADDON_NAME+=("Context7")
ADDON_KIND+=("mcp")
ADDON_DESC+=("Version-correct library documentation on demand. Guards against the model writing Java-era libGDX and stale KTX APIs from memory.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("gradle_mcp")
ADDON_NAME+=("gradle-mcp")
ADDON_KIND+=("mcp")
ADDON_DESC+=("Build and test loop for the agent: run Gradle tasks with captured output, inspect the project, browse dependency sources, and evaluate Kotlin against your real classpath. Needs JBang and JDK 21+.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("arch_lens")
ADDON_NAME+=("architecture-lens")
ADDON_KIND+=("skill")
ADDON_DESC+=("Two skills: a light design lens for routine work, and a five-step restructuring workflow with an 11-pattern reference for when a codebase needs surgery.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("superpowers")
ADDON_NAME+=("Obra Superpowers")
ADDON_KIND+=("plugin")
ADDON_DESC+=("Full development framework: brainstorming, planning, TDD, subagent execution with two-stage review, and verification before completion. Heavy; costs ambient tokens every session.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("caveman")
ADDON_NAME+=("caveman")
ADDON_KIND+=("plugin")
ADDON_DESC+=("Compresses the agent's prose without touching the code it writes. Complements ponytail: one shrinks what gets built, the other what gets said.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("handoff")
ADDON_NAME+=("handoff")
ADDON_KIND+=("skill")
ADDON_DESC+=("Compacts a session into a structured handoff document so you can start fresh without losing the thread. Installs per project, not globally, and its installer is interactive.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("mem0")
ADDON_NAME+=("mem0 memory")
ADDON_KIND+=("plugin")
ADDON_DESC+=("Persistent memory across sessions so you stop re-explaining project conventions. Choose the hosted service or a fully local SQLite vector store.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("damage_control")
ADDON_NAME+=("damage-control")
ADDON_KIND+=("plugin")
ADDON_DESC+=("Blocks destructive commands and protects secrets before they execute. Catches the specific catastrophes a generic bash prompt trains you to click through.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("warden")
ADDON_NAME+=("warden")
ADDON_KIND+=("plugin")
ADDON_DESC+=("Secret detection, redaction, sensitive-file blocking, and an audit trail. Relevant once signing keys or store credentials live in the tree.")
ADDON_DEFAULT+=("1")

ADDON_ID+=("ktx_conventions")
ADDON_NAME+=("KTX conventions")
ADDON_KIND+=("convention")
ADDON_DESC+=("Writes a KTX and libGDX house-style block for AGENTS.md, so the agent reaches for type-safe Kotlin builders instead of Java-era libGDX patterns.")
ADDON_DEFAULT+=("1")

# Installed last on purpose: DCP asks to sit at the end of the plugin array.
ADDON_ID+=("dcp")
ADDON_NAME+=("Dynamic Context Pruning")
ADDON_KIND+=("plugin")
ADDON_DESC+=("Prunes superseded tool output from the conversation as a session grows. Aimed at exactly what bloats JVM work: stale Gradle logs and stack traces.")
ADDON_DEFAULT+=("1")

ADDON_SELECTED=()

# Multi-select list. Fills ADDON_SELECTED with 0/1.
select_addons() {
  local count=${#ADDON_ID[@]} i reply token changed

  for ((i = 0; i < count; i++)); do
    ADDON_SELECTED[i]="${ADDON_DEFAULT[i]}"
  done

  while true; do
    for ((i = 0; i < count; i++)); do
      local mark tag name
      if [ "${ADDON_SELECTED[i]}" = "1" ]; then
        mark="${GREEN}[x]${RESET}"
        name="${BOLD}${ADDON_NAME[i]}${RESET}"
      else
        mark="${DIM}[ ]${RESET}"
        name="${ADDON_NAME[i]}"
      fi
      tag="${MAGENTA}${ADDON_KIND[i]}${RESET}"
      printf '   %s%d%s  %s %s  %s%s\n' "$CYAN" "$((i + 1))" "$RESET" "$mark" "$name" "$tag" "$RESET"
      printf '%s\n' "${ADDON_DESC[i]}" | fold -s -w 66 | sed "s/^/         ${GREY}/;s/\$/${RESET}/"
    done
    blank
    printf '  %stoggle:%s numbers   %sa%s all   %sn%s none   %senter%s accept\n' \
      "$DIM" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET"
    printf '  %s?%s Selection: ' "$CYAN" "$RESET"
    { read -r reply </dev/tty; } 2>/dev/null || reply=""

    case "$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')" in
      "")
        return 0
        ;;
      a|all)
        for ((i = 0; i < count; i++)); do ADDON_SELECTED[i]=1; done
        ;;
      n|none)
        for ((i = 0; i < count; i++)); do ADDON_SELECTED[i]=0; done
        ;;
      *)
        changed=0
        for token in $(printf '%s' "$reply" | tr ',' ' '); do
          case "$token" in
            ''|*[!0-9]*) continue ;;
          esac
          if [ "$token" -ge 1 ] && [ "$token" -le "$count" ]; then
            i=$((token - 1))
            if [ "${ADDON_SELECTED[i]}" = "1" ]; then
              ADDON_SELECTED[i]=0
            else
              ADDON_SELECTED[i]=1
            fi
            changed=1
          fi
        done
        [ "$changed" -eq 0 ] && note "Nothing matched. Enter numbers 1-$count, a, n, or press enter."
        ;;
    esac
    blank
  done
}

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG="$OPENCODE_CONFIG_DIR/opencode.json"

has() { command -v "$1" >/dev/null 2>&1; }

opencode_installed() { has opencode; }

opencode_version() { opencode --version 2>/dev/null | head -n 1; }

# Best guess at how opencode got here, for a tidier uninstall.
detect_install_method() {
  local path
  path=$(command -v opencode 2>/dev/null)
  if has brew && brew list --formula 2>/dev/null | grep -qx "opencode"; then
    printf 'homebrew'
  elif [ -n "$path" ] && case "$path" in "$HOME"/.opencode/*) true ;; *) false ;; esac; then
    printf 'script'
  elif has npm && npm ls -g --depth=0 2>/dev/null | grep -q "opencode-ai"; then
    printf 'npm'
  else
    printf 'unknown'
  fi
}

ensure_path() {
  hash -r 2>/dev/null || true
  if ! has opencode && [ -x "$HOME/.opencode/bin/opencode" ]; then
    export PATH="$HOME/.opencode/bin:$PATH"
    warn "opencode is not on your PATH yet."
    note "Added \$HOME/.opencode/bin for this run."
    if confirm "Append it to ~/.zshrc permanently?" y; then
      printf '\n# opencode\nexport PATH="$HOME/.opencode/bin:$PATH"\n' >>"$HOME/.zshrc"
      ok "Updated ~/.zshrc. Run 'source ~/.zshrc' in other shells."
    fi
  fi
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

require_brew() {
  has brew && return 0
  fail "Homebrew is not installed."
  info "Install it from https://brew.sh, or pick another source."
  return 1
}

install_opencode() {
  title "Install source" "Where opencode itself should come from."

  menu "Source" 1 \
    "Homebrew — anomalyco tap|brew install anomalyco/tap/opencode  ·  most up to date releases" \
    "Homebrew — official formula|brew install opencode  ·  maintained by Homebrew, updated less often" \
    "Install script|curl -fsSL https://opencode.ai/install | bash  ·  no package manager needed" \
    "npm|npm install -g opencode-ai"

  blank
  case "$MENU_CHOICE" in
    1)
      require_brew || return 1
      step "Installing from the anomalyco tap"
      run brew install anomalyco/tap/opencode || return 1
      ;;
    2)
      require_brew || return 1
      step "Installing the official Homebrew formula"
      run brew install opencode || return 1
      ;;
    3)
      step "Running the official install script"
      curl -fsSL https://opencode.ai/install | bash || return 1
      ;;
    4)
      has npm || { fail "npm is not installed."; return 1; }
      step "Installing opencode-ai globally with npm"
      run npm install -g opencode-ai || return 1
      ;;
  esac

  ensure_path
  if opencode_installed; then
    ok "opencode installed — $(opencode_version)"
    return 0
  fi
  fail "Install finished but 'opencode' is still not on the PATH."
  return 1
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

# Remove a path only if it lives under $HOME.
safe_rm() {
  local target="$1"
  [ -e "$target" ] || [ -L "$target" ] || return 0
  case "$target" in
    "$HOME"/*) ;;
    *) warn "Refusing to remove $target (outside \$HOME)"; return 0 ;;
  esac
  printf '    %s$ rm -rf %s%s\n' "$GREY" "$target" "$RESET"
  rm -rf "$target"
}

# Drop a block this script appended to ~/.zshrc: a comment line plus the
# export directly beneath it. Leaves anything the user wrote alone.
remove_zshrc_block() {
  local header="$1" file="$HOME/.zshrc" tmp
  [ -f "$file" ] || return 0
  grep -qxF "$header" "$file" 2>/dev/null || return 0

  tmp=$(mktemp) || return 1
  awk -v h="$header" '
    skip == 1 { skip = 0; next }
    $0 == h   { skip = 1; next }
    { print }
  ' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }

  # Never replace the file with nothing if awk misbehaved.
  if [ -s "$tmp" ]; then
    cat "$tmp" >"$file"
    rm -f "$tmp"
    ok "Removed the '$header' block from ~/.zshrc"
  else
    rm -f "$tmp"
    warn "Skipped ~/.zshrc; removing '$header' would have emptied it."
  fi
  return 0
}

# Everything the add-on installers put outside ~/.config/opencode, which the
# main uninstall does not reach.
uninstall_addons() {
  step "Removing add-on state outside the config directory"

  # The Kotlin extension lives in the editor, not under $HOME/.config.
  local cli installed
  if cli=$(editor_cli); then
    installed=$("$cli" --list-extensions 2>/dev/null)
    if printf '%s\n' "$installed" | grep -qix "$KOTLIN_EXT"; then
      if confirm "Remove the $KOTLIN_EXT extension from $cli?" y; then
        run_quiet "$cli" --uninstall-extension "$KOTLIN_EXT" \
          && ok "Removed $KOTLIN_EXT" \
          || warn "Could not remove it; use the Extensions view."
      fi
    fi
  fi

  # Globally installed npm add-on packages.
  if has npm && npm ls -g --depth=0 2>/dev/null | grep -q "opencode-mem0"; then
    run_quiet npm uninstall -g opencode-mem0 \
      && ok "Removed the opencode-mem0 package" \
      || warn "Could not remove opencode-mem0."
  fi

  # Serena keeps its global config and logs here, outside the project.
  safe_rm "$HOME/.serena"

  # Lines this script appended to the shell profile.
  remove_zshrc_block "# opencode"
  remove_zshrc_block "# opencode superpowers"
  remove_zshrc_block "# opencode mem0"

  # uv and JBang are general-purpose tools that other projects may rely on, and
  # you may well have had them before running this script, so they are opt-in.
  if has uvx || has jbang; then
    blank
    info "uv and JBang are what Serena and gradle-mcp run through."
    note "Other projects may use them, so they are kept by default."
    if confirm "Uninstall them too?" n; then
      if has brew; then
        brew list --formula 2>/dev/null | grep -qx "uv" \
          && run_quiet brew uninstall --force uv
        brew list --formula 2>/dev/null | grep -qx "jbang" \
          && run_quiet brew uninstall --force jbang
      fi
      # The standalone uv installer keeps everything under $HOME instead.
      safe_rm "$HOME/.local/bin/uv"
      safe_rm "$HOME/.local/bin/uvx"
      safe_rm "$HOME/.local/share/uv"
      safe_rm "$HOME/.cache/uv"
      remove_zshrc_block "# uv"
      hash -r 2>/dev/null || true
      ok "Removed the tooling."
    fi
  fi

  # Keys you exported yourself, outside the blocks this script owns.
  if grep -qE "MEM0_API_KEY|CONTEXT7_API_KEY" "$HOME/.zshrc" 2>/dev/null; then
    blank
    warn "~/.zshrc still exports MEM0_API_KEY or CONTEXT7_API_KEY."
    note "That line is outside the blocks this script wrote, so it is left alone."
  fi

  return 0
}

# Add-ons that write into project directories rather than your home directory.
# The script cannot know which projects those were, so it reports instead.
report_project_leftovers() {
  blank
  printf '  %sLeft in your projects%s\n' "$BOLD" "$RESET"
  info "These live in repositories, not \$HOME, so nothing here touched them:"
  note ".serena/           per-project Serena config"
  note ".agents/skills/    handoff and anything else from skills.sh"
  note "AGENTS.md          the KTX conventions block, if you appended it"
  note ".opencode/         any project-level config you created"
  blank
  note "Remove them per project if you want a clean slate."
}

uninstall_opencode() {
  title "Uninstall" "Removes opencode and everything this script installed."

  info "This will remove:"
  note "the opencode binary (Homebrew, npm, or install-script copy)"
  note_path "$OPENCODE_CONFIG_DIR"        "config, agents, commands, skills, plugins"
  note_path "$HOME/.local/share/opencode" "credentials, sessions, MCP auth"
  note_path "$HOME/.cache/opencode"       "caches"
  note_path "$HOME/.local/state/opencode" "logs and state"
  note_path "$HOME/.opencode"             "install-script binary"
  note_path "$HOME/.config/ponytail"      "ponytail mode and config"
  note_path "$HOME/.serena"               "Serena global config and logs"
  blank
  info "And, asking first for each:"
  note "the Kotlin by JetBrains extension in VS Code"
  note "the globally installed opencode-mem0 package"
  note "the PATH and telemetry lines this script added to ~/.zshrc"
  note "uv and JBang, if you want them gone as well"
  blank

  if ! confirm "Remove all of the above?" n; then
    info "Left everything alone."
    return 1
  fi
  blank

  # Providers, agents, and commands are easy to lose and annoying to rebuild.
  if [ -d "$OPENCODE_CONFIG_DIR" ]; then
    if confirm "Save a backup of your config first?" y; then
      local backup="$HOME/opencode-config-backup-$(date +%Y%m%d-%H%M%S).tgz"
      if tar -czf "$backup" -C "$HOME/.config" opencode 2>/dev/null; then
        ok "Backed up to $backup"
      else
        warn "Backup failed; stopping so nothing is lost."
        return 1
      fi
    fi
    blank
  fi

  # The built-in uninstaller handles whichever method was used, when present.
  if opencode_installed; then
    step "Running the built-in uninstaller"
    run opencode uninstall --force >/dev/null 2>&1 \
      && ok "Built-in uninstaller finished" \
      || note "Built-in uninstaller unavailable or failed; cleaning up manually."
  fi

  step "Removing packages"
  if has brew; then
    brew list --formula 2>/dev/null | grep -qx "opencode" \
      && run_quiet brew uninstall --force opencode
    brew list --formula 2>/dev/null | grep -q "anomalyco" \
      && run_quiet brew uninstall --force anomalyco/tap/opencode
  fi
  if has npm && npm ls -g --depth=0 2>/dev/null | grep -q "opencode-ai"; then
    run_quiet npm uninstall -g opencode-ai
  fi

  step "Removing files"
  safe_rm "$OPENCODE_CONFIG_DIR"
  safe_rm "$HOME/.local/share/opencode"
  safe_rm "$HOME/.cache/opencode"
  safe_rm "$HOME/.local/state/opencode"
  safe_rm "$HOME/.opencode"
  safe_rm "$HOME/.config/ponytail"

  blank
  uninstall_addons

  hash -r 2>/dev/null || true
  blank
  if opencode_installed; then
    warn "'opencode' still resolves to $(command -v opencode)"
    note "Remove that file by hand; it was installed outside \$HOME."
  else
    ok "opencode removed."
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Config helpers
# ---------------------------------------------------------------------------

config_has() {
  [ -f "$OPENCODE_CONFIG" ] && grep -q "$1" "$OPENCODE_CONFIG" 2>/dev/null
}

# Append a value to a top-level array in opencode.json, creating the file if
# needed. Uses node or python3 for the merge so existing settings survive.
config_add_to_array() {
  local key="$1" value="$2"

  mkdir -p "$OPENCODE_CONFIG_DIR"

  if [ ! -f "$OPENCODE_CONFIG" ]; then
    cat >"$OPENCODE_CONFIG" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "$key": ["$value"]
}
EOF
    return 0
  fi

  if has node; then
    node -e '
      const fs = require("fs");
      const [file, key, value] = process.argv.slice(1);
      const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
      cfg[key] = cfg[key] || [];
      if (!cfg[key].includes(value)) cfg[key].push(value);
      fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");
    ' "$OPENCODE_CONFIG" "$key" "$value" 2>/dev/null && return 0
  fi

  if has python3; then
    python3 - "$OPENCODE_CONFIG" "$key" "$value" <<'PY' 2>/dev/null && return 0
import json, sys
file, key, value = sys.argv[1:4]
with open(file) as f:
    cfg = json.load(f)
cfg.setdefault(key, [])
if value not in cfg[key]:
    cfg[key].append(value)
with open(file, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
  fi

  return 1
}

# opencode v2 nests servers under mcp.servers; v1 puts them directly under mcp.
mcp_nests_under_servers() {
  local major
  major=$(opencode --version 2>/dev/null | head -n 1 | tr -cd '0-9.' | cut -d. -f1)
  case "$major" in
    ''|*[!0-9]*) return 1 ;;
    *) [ "$major" -ge 2 ] ;;
  esac
}

# config_add_mcp <name> <json-object>
config_add_mcp() {
  local name="$1" blob="$2" nested=0
  mcp_nests_under_servers && nested=1

  mkdir -p "$OPENCODE_CONFIG_DIR"
  if [ ! -f "$OPENCODE_CONFIG" ]; then
    printf '{\n  "$schema": "https://opencode.ai/config.json"\n}\n' >"$OPENCODE_CONFIG"
  fi

  if has node; then
    node -e '
      const fs = require("fs");
      const [file, name, blob, nested] = process.argv.slice(1);
      const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
      cfg.mcp = cfg.mcp || {};
      let target = cfg.mcp;
      if (nested === "1") target = cfg.mcp.servers = cfg.mcp.servers || {};
      target[name] = JSON.parse(blob);
      fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");
    ' "$OPENCODE_CONFIG" "$name" "$blob" "$nested" 2>/dev/null && return 0
  fi

  if has python3; then
    python3 - "$OPENCODE_CONFIG" "$name" "$blob" "$nested" <<'PY' 2>/dev/null && return 0
import json, sys
file, name, blob, nested = sys.argv[1:5]
with open(file) as f:
    cfg = json.load(f)
mcp = cfg.setdefault("mcp", {})
target = mcp.setdefault("servers", {}) if nested == "1" else mcp
target[name] = json.loads(blob)
with open(file, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
  fi

  return 1
}

# Move one value to the end of a top-level array, preserving everything else.
config_move_to_array_end() {
  local key="$1" value="$2"
  [ -f "$OPENCODE_CONFIG" ] || return 0

  if has node; then
    node -e '
      const fs = require("fs");
      const [file, key, value] = process.argv.slice(1);
      const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
      if (!Array.isArray(cfg[key])) process.exit(0);
      const rest = cfg[key].filter((v) => v !== value);
      if (rest.length === cfg[key].length) process.exit(0);
      cfg[key] = [...rest, value];
      fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");
    ' "$OPENCODE_CONFIG" "$key" "$value" 2>/dev/null && return 0
  fi

  if has python3; then
    python3 - "$OPENCODE_CONFIG" "$key" "$value" <<'PY' 2>/dev/null && return 0
import json, sys
file, key, value = sys.argv[1:4]
with open(file) as f:
    cfg = json.load(f)
arr = cfg.get(key)
if isinstance(arr, list) and value in arr:
    cfg[key] = [v for v in arr if v != value] + [value]
    with open(file, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
PY
  fi

  return 0
}

# Fold a stray opencode.jsonc back into opencode.json.
#
# 'opencode plugin --global' and some third-party installers (caveman, DCP)
# write to opencode.jsonc or tui.json. When two config files both define
# "plugin", the arrays do not merge -- one shadows the other -- so plugins
# registered here would silently never load.
consolidate_config() {
  local jsonc="$OPENCODE_CONFIG_DIR/opencode.jsonc"
  local tui="$OPENCODE_CONFIG_DIR/tui.json"
  local moved=0

  has node || return 0

  if [ -f "$jsonc" ] && [ -f "$OPENCODE_CONFIG" ]; then
    if node -e '
      const fs = require("fs");
      const [main, extra] = process.argv.slice(1);
      const strip = (s) => s.replace(/^\s*\/\/.*$/gm, "");
      const cfg = JSON.parse(fs.readFileSync(main, "utf8"));
      const side = JSON.parse(strip(fs.readFileSync(extra, "utf8")));
      for (const [key, value] of Object.entries(side)) {
        if (key === "$schema") continue;
        if (Array.isArray(value)) {
          const arr = Array.isArray(cfg[key]) ? cfg[key] : [];
          cfg[key] = [...value, ...arr].filter((v, i, a) => a.indexOf(v) === i);
        } else if (cfg[key] === undefined) {
          cfg[key] = value;
        }
      }
      fs.writeFileSync(main, JSON.stringify(cfg, null, 2) + "\n");
    ' "$OPENCODE_CONFIG" "$jsonc" 2>/dev/null; then
      mv "$jsonc" "$jsonc.superseded" 2>/dev/null
      rm -f "$jsonc.bak"
      moved=1
    fi
  fi

  # tui.json is for TUI settings only; a "plugin" key there is never read.
  if [ -f "$tui" ] && grep -q '"plugin"' "$tui" 2>/dev/null; then
    if node -e '
      const fs = require("fs");
      const [main, tui] = process.argv.slice(1);
      const t = JSON.parse(fs.readFileSync(tui, "utf8"));
      if (!Array.isArray(t.plugin)) process.exit(0);
      const cfg = JSON.parse(fs.readFileSync(main, "utf8"));
      const arr = Array.isArray(cfg.plugin) ? cfg.plugin : [];
      cfg.plugin = [...arr, ...t.plugin].filter((v, i, a) => a.indexOf(v) === i);
      delete t.plugin;
      fs.writeFileSync(main, JSON.stringify(cfg, null, 2) + "\n");
      if (Object.keys(t).length === 0) fs.unlinkSync(tui);
      else fs.writeFileSync(tui, JSON.stringify(t, null, 2) + "\n");
    ' "$OPENCODE_CONFIG" "$tui" 2>/dev/null; then
      moved=1
    fi
  fi

  [ "$moved" -eq 1 ] && ok "Consolidated stray plugin entries into $OPENCODE_CONFIG"
  return 0
}

# ---------------------------------------------------------------------------
# Add-on installers
# ---------------------------------------------------------------------------

SKILLS_DIR="$OPENCODE_CONFIG_DIR/skills"

# Register an npm plugin in opencode.json.
add_plugin() {
  local pkg="$1"

  if config_has "$pkg"; then
    ok "Already present in $OPENCODE_CONFIG"
    return 0
  fi
  # Deliberately not using 'opencode plugin --global': it writes to
  # opencode.jsonc, and when both files define "plugin" the .jsonc array
  # shadows the .json one instead of merging. Keep all state in one file.
  if config_add_to_array "plugin" "$pkg"; then
    ok "Added to $OPENCODE_CONFIG"
    return 0
  fi
  fail "Could not update $OPENCODE_CONFIG automatically."
  note "Add this by hand:  { \"plugin\": [\"$pkg\"] }"
  return 1
}

# install_skills_from_git <repo-url> <subpath>:<skill-name> ...
install_skills_from_git() {
  local repo="$1"; shift
  local tmp pair src dest rc=0

  has git || { fail "git is required to install skills."; return 1; }
  tmp=$(mktemp -d) || return 1

  if ! run_quiet git clone --depth 1 "$repo" "$tmp/repo"; then
    rm -rf "$tmp"
    fail "Could not clone $repo"
    return 1
  fi

  mkdir -p "$SKILLS_DIR"
  for pair in "$@"; do
    src="${pair%%:*}"
    dest="${pair#*:}"
    if [ ! -d "$tmp/repo/$src" ]; then
      warn "$src is missing from the repository; skipping."
      rc=1
      continue
    fi
    rm -rf "${SKILLS_DIR:?}/$dest"
    cp -R "$tmp/repo/$src" "$SKILLS_DIR/$dest"
    ok "Installed skill: $dest"
  done

  rm -rf "$tmp"
  return "$rc"
}

# Serena runs through uvx, which ships as part of uv.
ensure_uv() {
  has uvx && return 0

  warn "uv is not installed; Serena runs through its uvx launcher."
  blank

  if has brew && confirm "Install uv with Homebrew?" y; then
    run brew install uv || warn "Homebrew could not install uv."
    hash -r 2>/dev/null || true
  fi

  if ! has uvx && confirm "Install uv with the official standalone installer?" y; then
    curl -LsSf https://astral.sh/uv/install.sh | sh || warn "The uv installer failed."
    # It drops binaries in ~/.local/bin without touching the current shell.
    if [ -d "$HOME/.local/bin" ]; then
      export PATH="$HOME/.local/bin:$PATH"
      hash -r 2>/dev/null || true
      if has uvx && ! grep -qxF '# uv' "$HOME/.zshrc" 2>/dev/null; then
        blank
        if confirm "Add ~/.local/bin to your PATH in ~/.zshrc?" y; then
          printf '\n# uv\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$HOME/.zshrc"
          ok "Updated ~/.zshrc"
        fi
      fi
    fi
  fi

  hash -r 2>/dev/null || true
  if has uvx; then
    ok "uv ready — $(uv --version 2>/dev/null | head -n 1)"
    return 0
  fi

  fail "uvx is still not on the PATH."
  note "Install uv from https://docs.astral.sh/uv/ and re-run this script."
  return 1
}

# Warn when a JVM tool will not start, without blocking the install.
check_java() {
  local want="$1" have
  if ! has java; then
    warn "No java on PATH; this add-on needs JDK $want or newer to run."
    return 1
  fi
  have=$(java -version 2>&1 | head -n 1 | sed -n 's/.*"\([0-9][0-9]*\).*/\1/p')
  if [ -n "$have" ] && [ "$have" -lt "$want" ] 2>/dev/null; then
    warn "Java $have found, but this add-on needs $want or newer."
    return 1
  fi
  return 0
}

PONYTAIL_PKG="@dietrichgebert/ponytail"

install_addon_ponytail() {
  step "Installing ponytail"

  add_plugin "$PONYTAIL_PKG" || return 1

  # Default intensity. full is ponytail's own default, so only write a config
  # file when the user wants something else.
  blank
  info "ponytail intensity for new sessions:"
  menu "Level" 2 \
    "lite|Gentle. Nudges toward smaller solutions." \
    "full|The standard ruleset. ponytail's own default." \
    "ultra|Maximum. For when the codebase has wronged you personally." \
    "off|Installed but silent until you run /ponytail."

  local mode
  case "$MENU_CHOICE" in
    1) mode="lite" ;;
    2) mode="full" ;;
    3) mode="ultra" ;;
    4) mode="off" ;;
  esac

  blank
  if [ "$mode" = "full" ]; then
    note "Keeping the built-in default (full); no config file needed."
  else
    mkdir -p "$HOME/.config/ponytail"
    printf '{\n  "defaultMode": "%s"\n}\n' "$mode" >"$HOME/.config/ponytail/config.json"
    ok "Default level set to $mode in ~/.config/ponytail/config.json"
  fi

  return 0
}

# The free Apache-2.0 Kotlin server. Its sibling, JetBrains.intellij-server,
# covers Java and mixed projects but heads toward a paid Ultimate subscription.
KOTLIN_EXT="JetBrains.kotlin-server"
KOTLIN_EXT_OLD="jetbrains.kotlin"

# First VS Code-family CLI on the PATH.
editor_cli() {
  local cli
  for cli in code cursor windsurf codium; do
    has "$cli" && { printf '%s' "$cli"; return 0; }
  done
  return 1
}

install_addon_kotlin_vscode() {
  step "Installing Kotlin by JetBrains"

  local cli
  if ! cli=$(editor_cli); then
    fail "No VS Code command found on your PATH."
    note "In VS Code press Cmd+Shift+P and run"
    note "\"Shell Command: Install 'code' command in PATH\", then re-run this script."
    return 1
  fi

  # Installing into the wrong editor is easy to do and confusing to debug.
  if [ "$cli" != "code" ]; then
    warn "'code' is not on your PATH, but '$cli' is."
    note "Extensions installed with '$cli' go to that editor, not VS Code."
    if ! confirm "Install into $cli instead?" n; then
      note "In VS Code run Cmd+Shift+P, \"Shell Command: Install 'code' command in PATH\"."
      return 1
    fi
  fi

  local installed
  installed=$("$cli" --list-extensions 2>/dev/null)

  # The new server refuses to activate while the old extension is present.
  if printf '%s\n' "$installed" | grep -qix "$KOTLIN_EXT_OLD"; then
    warn "The older $KOTLIN_EXT_OLD extension is installed."
    note "$KOTLIN_EXT cannot activate while it is there."
    if confirm "Remove the old one?" y; then
      run_quiet "$cli" --uninstall-extension "$KOTLIN_EXT_OLD" \
        && ok "Removed $KOTLIN_EXT_OLD" \
        || warn "Could not remove it; do it from the Extensions view."
    fi
  fi

  if printf '%s\n' "$installed" | grep -qix "$KOTLIN_EXT"; then
    ok "Already installed"
  else
    if ! run_quiet "$cli" --install-extension "$KOTLIN_EXT"; then
      fail "Could not install $KOTLIN_EXT."
      note "Search for \"Kotlin by JetBrains\" in the Extensions view instead."
      return 1
    fi
    ok "Installed $KOTLIN_EXT"
  fi

  note "Open any .kt file to start it. The first Gradle import takes a few minutes."
  return 0
}

install_addon_serena() {
  step "Configuring Serena"

  ensure_uv || return 1
  check_java 21 || note "Serena downloads its own JRE if it cannot find one."

  # opencode does not always inherit your shell PATH, so pin the absolute path.
  local uvx_path
  uvx_path=$(command -v uvx)

  # 'ide' is Serena's generic context for coding agents; it drops the tools
  # opencode already provides rather than duplicating them.
  if ! config_add_mcp serena "{
    \"type\": \"local\",
    \"command\": [\"$uvx_path\", \"--from\", \"git+https://github.com/oraios/serena\", \"serena\", \"start-mcp-server\", \"--context\", \"ide\"],
    \"enabled\": true
  }"; then
    fail "Could not write the serena entry to $OPENCODE_CONFIG."
    return 1
  fi
  ok "Added serena to $OPENCODE_CONFIG"

  blank
  info "One step per project, from the project root:"
  note "uvx --from git+https://github.com/oraios/serena serena project generate-yml"
  note "then set  languages: [\"kotlin\"]  in .serena/project.yml"
  note "Raise the heap there too; the Kotlin server defaults to -Xmx2G."
  return 0
}

install_addon_context7() {
  step "Configuring Context7"

  local blob='{"type":"remote","url":"https://mcp.context7.com/mcp","enabled":true}'
  blank
  if confirm "Do you have a Context7 API key for higher rate limits?" n; then
    blob='{"type":"remote","url":"https://mcp.context7.com/mcp","headers":{"CONTEXT7_API_KEY":"{env:CONTEXT7_API_KEY}"},"enabled":true}'
    note "Reads \$CONTEXT7_API_KEY at runtime; export it from your shell profile."
  fi

  if ! config_add_mcp context7 "$blob"; then
    fail "Could not write the context7 entry to $OPENCODE_CONFIG."
    return 1
  fi
  ok "Added context7 to $OPENCODE_CONFIG"
  note "Add 'use context7' to a prompt, or tell AGENTS.md to prefer it for docs."
  return 0
}

install_addon_gradle_mcp() {
  step "Configuring gradle-mcp"

  if ! has jbang; then
    warn "JBang is not installed; gradle-mcp runs through it."
    if has brew && confirm "Install JBang with Homebrew now?" y; then
      run brew install jbang || return 1
      hash -r 2>/dev/null || true
    else
      note "Install it from https://www.jbang.dev, then re-run this script."
      return 1
    fi
  fi
  check_java 21 || note "JBang can install a JDK for you: jbang jdk install 21"

  local jbang_path
  jbang_path=$(command -v jbang)

  if ! config_add_mcp gradle "{
    \"type\": \"local\",
    \"command\": [\"$jbang_path\", \"run\", \"--quiet\", \"--fresh\", \"gradle-mcp@rnett\"],
    \"enabled\": true
  }"; then
    fail "Could not write the gradle entry to $OPENCODE_CONFIG."
    return 1
  fi
  ok "Added gradle to $OPENCODE_CONFIG"
  note "First run downloads the server, so expect a slow initial start."
  note "If security software triggers CDS errors, add --no-cds to the command."
  return 0
}

install_addon_arch_lens() {
  step "Installing the architecture skills"

  # The project ships two skills but its README copies only the second one;
  # architecture-lens is the one meant for everyday use.
  install_skills_from_git "https://github.com/zachcr-ws/improve-code-architecture.git" \
    "skills/architecture-lens:architecture-lens" \
    "skills/improve-code-architecture:improve-code-architecture" || return 1

  note "architecture-lens is the everyday lens; the other is the escalation path."
  return 0
}

install_addon_superpowers() {
  step "Installing Obra Superpowers"

  local spec="superpowers@git+https://github.com/obra/superpowers.git"
  if config_has "obra/superpowers"; then
    ok "Already present in $OPENCODE_CONFIG"
  elif config_add_to_array "plugin" "$spec"; then
    ok "Added to $OPENCODE_CONFIG"
  else
    fail "Could not update $OPENCODE_CONFIG automatically."
    note "Add this by hand:  { \"plugin\": [\"$spec\"] }"
    return 1
  fi

  note "Installs from git on the next start and registers its skills itself."
  blank
  if confirm "Disable Superpowers telemetry in ~/.zshrc?" y; then
    if grep -q "SUPERPOWERS_DISABLE_TELEMETRY" "$HOME/.zshrc" 2>/dev/null; then
      ok "Already set."
    else
      printf '\n# opencode superpowers\nexport SUPERPOWERS_DISABLE_TELEMETRY=1\n' >>"$HOME/.zshrc"
      ok "Set SUPERPOWERS_DISABLE_TELEMETRY=1"
    fi
  fi
  return 0
}

install_addon_caveman() {
  step "Installing caveman"

  if ! has npx; then
    fail "npx not found; caveman ships its own Node installer."
    return 1
  fi

  blank
  info "caveman's installer runs interactively and patches opencode.json itself."
  run npx -y github:JuliusBrussee/caveman -- --only opencode || {
    fail "The caveman installer did not finish."
    return 1
  }
  ok "caveman installed"
  note "Installs a plugin, slash commands, and an AGENTS.md ruleset."
  note "Per-turn reinforcement uses the same system-prompt hook as ponytail;"
  note "the two are designed to run together."
  return 0
}

install_addon_handoff() {
  step "Installing handoff"

  if ! has npx; then
    fail "npx not found; the skills.sh installer needs it."
    return 1
  fi

  warn "This installs into the current directory, not your global config."
  note "Working directory: $(pwd)"
  blank
  if ! confirm "Install handoff here?" n; then
    note "Re-run this script from your project root, or install it later with:"
    note "npx skills@latest add mattpocock/skills --skill handoff"
    return 0
  fi

  run npx -y skills@latest add mattpocock/skills --skill handoff || {
    fail "The skills installer did not finish."
    note "Run it by hand: npx skills@latest add mattpocock/skills"
    return 1
  }
  ok "handoff installed"
  return 0
}

install_addon_mem0() {
  local mem0_key=""

  step "Installing persistent memory"

  blank
  info "Two implementations, and the difference is where your memories live:"
  menu "Backend" 2 \
    "mem0 hosted|Managed service. Nine memory tools and lifecycle hooks. Needs a free API key." \
    "opencode-mem0 local|SQLite and a local vector index. No account, no network, nothing leaves the machine."

  # Both backends block on their store while loading, so an unconfigured mem0
  # hangs opencode at startup instead of degrading. Register the plugin only
  # once its backend is known to be reachable.
  blank
  case "$MENU_CHOICE" in
    1)
      if [ -z "$MEM0_API_KEY" ]; then
        warn "MEM0_API_KEY is not set, and mem0 hosted hangs at startup without it."
        note "Get a free key at https://app.mem0.ai/dashboard/api-keys"
        blank
        printf 'Paste your MEM0_API_KEY (or press Enter to skip): '
        { read -r mem0_key </dev/tty; } 2>/dev/null || mem0_key=""
      else
        mem0_key="$MEM0_API_KEY"
        ok "Using MEM0_API_KEY from the environment."
      fi

      if [ -z "$mem0_key" ]; then
        blank
        warn "Skipping mem0 — nothing was added to your config."
        note "Export MEM0_API_KEY and re-run this installer to enable it."
        return 0
      fi

      export MEM0_API_KEY="$mem0_key"
      if ! grep -q "MEM0_API_KEY" "$HOME/.zshrc" 2>/dev/null; then
        if confirm "Save MEM0_API_KEY to ~/.zshrc?" y; then
          printf '\n# opencode mem0\nexport MEM0_API_KEY="%s"\n' "$mem0_key" >>"$HOME/.zshrc"
          ok "Saved to ~/.zshrc"
        else
          warn "Export MEM0_API_KEY yourself, or opencode will hang on startup."
        fi
      fi
      add_plugin "@mem0/opencode-plugin" || return 1
      ;;
    2)
      has npm || { fail "npm is required for opencode-mem0."; return 1; }
      run_quiet npm install -g opencode-mem0 || {
        fail "npm install failed."
        return 1
      }
      # init creates the SQLite store the plugin blocks on. No store, no plugin.
      if ! run_quiet npx opencode-mem0 init; then
        blank
        fail "'npx opencode-mem0 init' failed, so the local store does not exist."
        warn "Skipping mem0 — registering it now would hang opencode at startup."
        note "Run 'npx opencode-mem0 init' by hand, then re-run this installer."
        return 1
      fi
      ok "Initialised the local store"
      add_plugin "opencode-mem0" || return 1
      ;;
  esac
  return 0
}

install_addon_damage_control() {
  step "Installing damage-control"
  add_plugin "opencode-damage-control" || return 1
  note "Tune it later in ~/.config/opencode/damage-control.json"
  return 0
}

install_addon_warden() {
  step "Installing warden"
  add_plugin "opencode-warden" || return 1
  note "Its LLM risk evaluation adds latency and cost per call; configure"
  note "it in ~/.config/opencode/opencode-warden.json"
  return 0
}

install_addon_ktx_conventions() {
  step "Writing the KTX conventions block"

  local snippet="$OPENCODE_CONFIG_DIR/ktx-conventions.md"
  mkdir -p "$OPENCODE_CONFIG_DIR"

  cat >"$snippet" <<'MD'
## Kotlin and libGDX conventions

This project is Kotlin-first libGDX. Most libGDX material online is Java-era;
prefer the KTX idiom over the Java pattern it replaces.

- Use KTX modules where one exists: `ktx-scene2d` for UI, `ktx-async` for
  coroutines, `ktx-assets` for loading and disposal, `ktx-math` for vector and
  matrix operators, `ktx-box2d` for physics bodies.
- Build Scene2D UI with the `scene2d { }` type-safe builders, not by
  constructing widgets and calling `add()` in sequence.
- Manage lifetimes with `use { }` and the KTX disposal helpers rather than
  hand-written `dispose()` chains.
- Prefer coroutines over `Timer`, `Thread`, and manual callback plumbing.
- Use operator overloads on `Vector2` and `Vector3` instead of `add()`,
  `scl()`, and friends.
- Keep rendering separate from game logic so logic stays testable under the
  headless backend without a GL context.
- Reuse a libGDX or KTX built-in before writing a utility of your own.
MD

  ok "Wrote $snippet"

  # Offer to append it if this looks like the game project.
  if [ -f "./build.gradle.kts" ] || [ -f "./build.gradle" ] || [ -f "./settings.gradle.kts" ]; then
    blank
    info "This directory looks like a Gradle project."
    if confirm "Append the block to ./AGENTS.md?" y; then
      if [ -f "./AGENTS.md" ] && grep -q "Kotlin and libGDX conventions" "./AGENTS.md" 2>/dev/null; then
        ok "AGENTS.md already has it."
      else
        printf '\n' >>"./AGENTS.md"
        cat "$snippet" >>"./AGENTS.md"
        ok "Appended to ./AGENTS.md"
      fi
    fi
  else
    note "Paste it into your project's AGENTS.md after running /init."
  fi
  return 0
}

install_addon_dcp() {
  step "Installing Dynamic Context Pruning"
  # @latest keeps it refreshed on every start, which is what its docs advise.
  add_plugin "@tarquinen/opencode-dcp@latest" || return 1
  note "Verify with /dcp once opencode restarts."
  return 0
}

install_addons() {
  local count=${#ADDON_ID[@]} i any=0

  # Absorb anything a previous run or an earlier manual setup left behind.
  consolidate_config

  for ((i = 0; i < count; i++)); do
    [ "${ADDON_SELECTED[i]}" = "1" ] || continue
    any=1
    blank
    "install_addon_${ADDON_ID[i]}" || warn "${ADDON_NAME[i]} did not install cleanly."
  done

  # Third-party installers (caveman, DCP) write their own config files.
  consolidate_config

  # DCP asks to load last so it does not interfere with OAuth plugins, and
  # anything installed after it would otherwise land further down the array.
  if config_has "@tarquinen/opencode-dcp"; then
    config_move_to_array_end "plugin" "@tarquinen/opencode-dcp@latest"
  fi

  [ "$any" -eq 0 ] && info "No add-ons selected."
  return 0
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

addon_selected() {
  local i
  for ((i = 0; i < ${#ADDON_ID[@]}; i++)); do
    if [ "${ADDON_ID[i]}" = "$1" ]; then
      [ "${ADDON_SELECTED[i]:-0}" = "1" ]
      return
    fi
  done
  return 1
}

STEP_N=0
next_step() {
  STEP_N=$((STEP_N + 1))
  printf '   %s%d%s  %s%-34s%s %s\n' "$CYAN" "$STEP_N" "$RESET" "$BOLD" "$1" "$RESET" "$2"
}

summary() {
  local i
  title "Done" "Where things stand."

  ok "opencode $(opencode_version)"
  for ((i = 0; i < ${#ADDON_ID[@]}; i++)); do
    [ "${ADDON_SELECTED[i]:-0}" = "1" ] && ok "${ADDON_NAME[i]} (${ADDON_KIND[i]})"
  done

  blank
  printf '  %sNext steps%s\n' "$BOLD" "$RESET"
  next_step "opencode auth login" "connect a model provider"
  next_step "cd <your project>" "then run opencode"
  next_step "/init" "let it write AGENTS.md for the repo"

  addon_selected ponytail && next_step "/ponytail-help" "the ponytail commands"
  addon_selected dcp && next_step "/dcp" "confirm context pruning is live"

  if addon_selected serena; then
    blank
    printf '  %sPer project, before Serena is useful%s\n' "$BOLD" "$RESET"
    note "uvx --from git+https://github.com/oraios/serena serena project generate-yml"
    note "then set languages: [\"kotlin\"] in .serena/project.yml"
  fi

  if addon_selected mem0 || addon_selected context7; then
    blank
    printf '  %sKeys to set%s\n' "$BOLD" "$RESET"
    addon_selected mem0 && note "MEM0_API_KEY  (only for the hosted backend)"
    addon_selected context7 && note "CONTEXT7_API_KEY  (optional, raises rate limits)"
  fi

  blank
  info "MCP servers and plugins load on the next start, so restart opencode."
  blank
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF

  ${BOLD}${SCRIPT_NAME}${RESET} — install opencode and its add-ons on macOS

  ${BOLD}Usage${RESET}
    ./${SCRIPT_NAME} [options]

  ${BOLD}Options${RESET}
    --no-color   plain output, no ANSI escapes
    -h, --help   this message

  Detects an existing install and offers to keep or remove it, lets you pick
  the install source, then installs any add-ons you select.

EOF
}

main() {
  setup_colors

  while [ $# -gt 0 ]; do
    case "$1" in
      --no-color) USE_COLOR=0; setup_colors ;;
      -h|--help)  usage; exit 0 ;;
      *)          setup_colors; usage; die "Unknown option: $1" ;;
    esac
    shift
  done

  [ "$(uname -s)" = "Darwin" ] || warn "This script targets macOS; continuing anyway."

  banner

  if opencode_installed; then
    local method
    method=$(detect_install_method)
    title "Existing install" "opencode is already on this machine."
    ok "$(opencode_version)"
    note "binary:  $(command -v opencode)"
    note "source:  $method"
    note "config:  $OPENCODE_CONFIG_DIR"
    blank

    menu "What now" 1 \
      "Keep it and continue|Move on to add-ons, leaving opencode as it is." \
      "Reinstall|Remove everything, then install fresh from a source you pick." \
      "Uninstall and quit|Remove opencode and all of its data, then stop." \
      "Quit|Change nothing."

    blank
    case "$MENU_CHOICE" in
      1)
        info "Keeping the existing install."
        ;;
      2)
        uninstall_opencode || die "Reinstall cancelled."
        install_opencode || die "Install failed."
        ;;
      3)
        uninstall_opencode || exit 0
        report_project_leftovers
        exit 0
        ;;
      4)
        blank; info "Nothing changed."; blank; exit 0
        ;;
    esac
  else
    title "No install found" "'opencode' is not on your PATH."
    install_opencode || die "Install failed."
  fi

  title "Add-ons" "Plugins, MCP servers, and skills to install alongside opencode."
  select_addons
  blank
  install_addons

  summary
}

main "$@"
