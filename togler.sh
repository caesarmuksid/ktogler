#!/bin/bash
# Togler - KWin Configuration Reloader
# Usage: ./togler.sh [command]

SCRIPT_NAME="togler"
CONFIG_FILE="$HOME/.local/share/kwin/scripts/$SCRIPT_NAME/togler-config.json"
PROJECT_CONFIG="$(dirname "$0")/togler-config.example.json"
KCONF_GROUP="Script-$SCRIPT_NAME"
KCONF_KEY="config"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

kwin_config_get() {
  kreadconfig6 --file kwinrc --group "$KCONF_GROUP" --key "$KCONF_KEY" 2>/dev/null
}

seed_installed_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Creating config from template: $CONFIG_FILE${NC}"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cp "$PROJECT_CONFIG" "$CONFIG_FILE" 2>/dev/null || {
      echo -e "${RED}Error: Could not create config file${NC}"
      exit 1
    }
  fi
}

push_to_kwinrc() {
  local src="$1"
  kwriteconfig6 --file kwinrc --group "$KCONF_GROUP" --key "$KCONF_KEY" "$(tr -d '\n' < "$src")"
  echo -e "${GREEN}✓ Pushed to kwinrc [$KCONF_GROUP]${NC}"
}

# Map a key name (letter, digit, or F1-F99) to its Qt key code
keycode() {
  local k="$1"
  case "$k" in
  [a-zA-Z]) printf '%d' "'$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')" ;;
  [0-9]) printf '%d' "'$k" ;;
  [Ff][0-9] | [Ff][0-9][0-9]) printf '%d' "$((16777263 + ${k#[Ff]}))" ;;
  *) return 1 ;;
  esac
}

# Check whether a key combination is free to register
check_key() {
  local combo="${1:-}"
  if [ -z "$combo" ]; then
    echo -e "${RED}Usage: $0 check-key <combo>   e.g. Meta+S, Ctrl+Alt+T, Meta+F12${NC}"
    return 1
  fi

  local -a parts
  IFS='+' read -ra parts <<< "$combo"
  local n=${#parts[@]} i mods=0 kcode code

  for ((i = 0; i < n - 1; i++)); do
    case "${parts[i],,}" in
    meta | super | win) mods=$((mods + 268435456)) ;;
    ctrl | control) mods=$((mods + 67108864)) ;;
    alt) mods=$((mods + 134217728)) ;;
    shift) mods=$((mods + 33554432)) ;;
    *)
      echo -e "${RED}Unknown modifier: ${parts[i]}${NC} (use Meta, Ctrl, Alt, Shift)"
      return 1
      ;;
    esac
  done

  if ! kcode="$(keycode "${parts[n - 1]}")"; then
    echo -e "${RED}Unsupported key: ${parts[n - 1]}${NC} (letters, digits, F1-F99)"
    return 1
  fi
  code=$((mods + kcode))

  if qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.isGlobalShortcutAvailable "$code" kwin 2>/dev/null | grep -qi true; then
    echo -e "${GREEN}✓ $combo is free${NC} (code $code)"
  else
    echo -e "${RED}✗ $combo is taken${NC} (code $code)"
    local holders
    holders="$(qdbus6 --literal org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.getGlobalShortcutsByKey "$code" 2>/dev/null | grep -oE '"[^"]+", "[^"]+", "[^"]+"')"
    if [ -n "$holders" ]; then
      echo "  Held by:"
      printf '%s\n' "$holders" | sed -E 's/^"([^"]*)", "[^"]*", "([^"]*)".*/    - \1 (\2)/' | sort -u
    fi
  fi
}

show_help() {
  echo -e "${GREEN}Togler - KWin Window Toggle Manager${NC}"
  echo ""
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo -e "  ${YELLOW}reload${NC}      - Reload KWin to apply config changes"
  echo -e "  ${YELLOW}edit${NC}        - Edit config file (saves + pushes to kwinrc)"
  echo -e "  ${YELLOW}status${NC}      - Show current configuration"
  echo -e "  ${YELLOW}sync${NC}        - Seed config from example (only if kwinrc config unset)"
  echo -e "  ${YELLOW}push${NC}        - Push config file into kwinrc (overwrite)"
  echo -e "  ${YELLOW}validate${NC}    - Validate JSON configuration"
  echo -e "  ${YELLOW}check-key${NC}   - Check if a key combination is free (e.g. Meta+S)"
  echo -e "  ${YELLOW}list${NC}        - List available window classes"
  echo -e "  ${YELLOW}help${NC}        - Show this help message"
  echo ""
}

clean_stale_shortcuts() {
  local cfg expected name
  cfg="$(kwin_config_get)"
  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}  jq not available; skipping stale shortcut cleanup (install jq)${NC}"
    return 0
  fi
  if [ -n "$cfg" ]; then
    expected="$(echo "$cfg" | jq -r '.apps | keys[]' 2>/dev/null | while read -r n; do
      printf 'Togler%s\n' "$(printf '%s' "$n" | sed 's/^./\U&/')"
    done)"
  fi
  for name in $(qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.shortcutNames 2>/dev/null | grep '^Togler'); do
    if ! printf '%s\n' "$expected" | grep -qx "$name"; then
      qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister kwin "$name" >/dev/null 2>&1
      echo -e "${YELLOW}  ✓ Removed stale shortcut: $name${NC}"
    fi
  done
}

reload_kwin() {
  echo -e "${GREEN}Reloading KWin...${NC}"
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$SCRIPT_NAME" >/dev/null 2>&1
  qdbus6 org.kde.KWin /KWin reconfigure
  sleep 1
  clean_stale_shortcuts
  echo -e "${GREEN}✓ KWin reloaded${NC}"
  echo ""
  echo "Check logs with:"
  echo -e "  ${YELLOW}journalctl --user -f | grep -i togler${NC}"
}

edit_config() {
  seed_installed_config

  ${EDITOR:-nano} "$CONFIG_FILE"

  echo ""
  push_to_kwinrc "$CONFIG_FILE"

  read -p "Reload KWin now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    reload_kwin
  fi
}

sync_config() {
  seed_installed_config

  if [ -n "$(kwin_config_get)" ]; then
    echo -e "${YELLOW}! kwinrc config already set, keeping it:${NC} $KCONF_GROUP/$KCONF_KEY"
    echo -e "Overwrite it with: ${YELLOW}$0 push${NC}"
    return 0
  fi

  push_to_kwinrc "$CONFIG_FILE"

  read -p "Reload KWin now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    reload_kwin
  fi
}

push_config() {
  seed_installed_config
  push_to_kwinrc "$CONFIG_FILE"

  read -p "Reload KWin now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    reload_kwin
  fi
}

show_status() {
  echo -e "${GREEN}Current Configuration (kwinrc [$KCONF_GROUP/$KCONF_KEY]):${NC}"
  echo ""

  local val
  val="$(kwin_config_get)"

  if [ -n "$val" ]; then
    echo "$val" | jq . 2>/dev/null || printf '%s\n' "$val"
  else
    echo -e "${YELLOW}No config set in kwinrc${NC}"
    echo "No shortcuts are registered until a config is set: $0 sync"
  fi

  echo ""
  echo -e "${BLUE}Plugin status:${NC}"
  kreadconfig6 --file kwinrc --group Plugins --key ${SCRIPT_NAME}Enabled |
    grep -q "true" && echo -e "  ${GREEN}✓ Enabled${NC}" || echo -e "  ${RED}✗ Disabled${NC}"
}

validate_config() {
  local val src_label
  val="$(kwin_config_get)"
  src_label="kwinrc [$KCONF_GROUP]"

  if [ -z "$val" ] && [ -f "$CONFIG_FILE" ]; then
    val="$(cat "$CONFIG_FILE")"
    src_label="$CONFIG_FILE"
  fi

  if [ -z "$val" ]; then
    echo -e "${YELLOW}No config set. Run: $0 sync${NC}"
    exit 1
  fi

  echo -e "${GREEN}Validating configuration ($src_label)...${NC}"

  if echo "$val" | jq empty 2>/dev/null; then
    echo -e "${GREEN}✓ JSON syntax is valid${NC}"

    if echo "$val" | jq -e '.apps' >/dev/null 2>&1; then
      echo -e "${GREEN}✓ 'apps' section found${NC}"
    else
      echo -e "${RED}✗ Missing 'apps' section${NC}"
    fi

    if echo "$val" | jq -e '.shortcuts' >/dev/null 2>&1; then
      echo -e "${GREEN}✓ 'shortcuts' section found${NC}"
    else
      echo -e "${RED}✗ Missing 'shortcuts' section${NC}"
    fi
  else
    echo -e "${RED}✗ Invalid JSON syntax${NC}"
    exit 1
  fi
}

list_windows() {
  echo -e "${GREEN}Currently open windows and their resource classes:${NC}"
  echo ""
  qdbus6 org.kde.KWin /KWin org.kde.KWin.queryWindowInfo | grep -E "(caption|resourceClass)" |
    awk 'NR%2{printf "  %s → ",$0;next;}1'
  echo ""
  echo -e "${BLUE}Tip:${NC} Use the resourceClass value in your config file"
}

# Main script logic
case "${1:-help}" in
reload)
  reload_kwin
  ;;
edit)
  edit_config
  ;;
status)
  show_status
  ;;
sync)
  sync_config
  ;;
push)
  push_config
  ;;
validate)
  validate_config
  ;;
check-key)
  check_key "${2:-}"
  ;;
list)
  list_windows
  ;;
help | --help | -h)
  show_help
  ;;
*)
  echo -e "${RED}Unknown command: $1${NC}"
  echo ""
  show_help
  exit 1
  ;;
esac
