#!/usr/bin/env bash
# ktogler - KWin application window toggler.
#
# End-user installer / uninstaller. Run from a source checkout:
#
#   ./install.sh            # build + install + enable + seed config + reload
#   ./install.sh --uninstall  # disable, remove shortcuts and the package
#   ./install.sh --purge      # uninstall and also delete your config
#
# Requires KDE Plasma 6 / KWin with scripting, and the KDE CLI tools:
#   kpackagetool6, kwriteconfig6, qdbus6  (and optionally jq).
# Set NO_COLOR=1 to disable colored output.

set -e

if [ -n "${NO_COLOR:-}" ]; then
  GREEN=""
  YELLOW=""
  RED=""
  NC=""
else
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  NC='\033[0m'
fi

SCRIPT_NAME="ktogler"

die() {
  echo -e "${RED}✗ $*${NC}" >&2
  exit 1
}

case "${1:-install}" in
-h | --help | help)
  printf '%s\n' \
    "Usage: $0 [install|--uninstall|--purge|help]" \
    "" \
    "  install       (default) build + install + enable + seed config + reload" \
    "  --uninstall   disable, remove shortcuts and the package (keeps config)" \
    "  --purge       uninstall and delete the configuration too" \
    "  help          show this help"
  exit 0
  ;;
esac

# Make sure we are in the project root regardless of how the script is invoked.
cd "$(dirname "$0")"

[ -f Makefile ] || die "install.sh must be run from the ktogler source root"

for tool in kpackagetool6 kwriteconfig6 qdbus6 make; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: ${tool}"
done
command -v jq >/dev/null 2>&1 \
  && echo -e "${YELLOW}  jq found (stale shortcut cleanup enabled)${NC}" \
  || echo -e "${YELLOW}  jq not found; install it for stale shortcut cleanup${NC}"

install_plugin() {
  echo -e "${GREEN}▶ Building package...${NC}"
  make build
  echo -e "${GREEN}▶ Installing ${SCRIPT_NAME}...${NC}"
  make install
  echo -e "${GREEN}▶ Enabling ${SCRIPT_NAME}...${NC}"
  make enable
  echo -e "${GREEN}▶ Seeding example config into kwinrc (skips if already set)...${NC}"
  make config-sync
  echo -e "${GREEN}▶ Reloading KWin...${NC}"
  make reload
  echo ""
  echo -e "${GREEN}✓ ${SCRIPT_NAME} is installed and enabled.${NC}"
  echo ""
  echo "Next steps:"
  echo -e "  • Verify:     ${YELLOW}./ktogler.sh status${NC}"
  echo -e "  • Edit config:${YELLOW}make config-edit${NC} (or ${YELLOW}./ktogler.sh edit${NC})"
  echo -e "  • Reload:     ${YELLOW}make reload${NC}"
  echo -e "  • Logs:       ${YELLOW}journalctl --user -f | grep -i ktogler${NC}"
}

case "${1:-install}" in
install)
  install_plugin
  ;;
--uninstall | uninstall)
  echo -e "${GREEN}▶ Uninstalling ${SCRIPT_NAME}...${NC}"
  make uninstall
  echo -e "${GREEN}✓ Uninstalled (config kept; use --purge to remove it too).${NC}"
  ;;
--purge | purge)
  echo -e "${GREEN}▶ Purging ${SCRIPT_NAME}...${NC}"
  make purge
  echo -e "${GREEN}✓ Uninstalled and purged.${NC}"
  ;;
*)
  echo -e "${RED}Unknown option: $1${NC}" >&2
  printf 'Usage: %s [install|--uninstall|--purge]\n' "$0" >&2
  exit 1
  ;;
esac