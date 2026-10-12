# ktogler - Build System
# Usage: make [target]

# Variables
SCRIPT_NAME = ktogler
SHORTCUT_PREFIX = Ktogler
VERSION = $(shell cat VERSION)
BUILD_DIR = build
PACKAGE_NAME = $(SCRIPT_NAME)-$(VERSION).kwinscript
INSTALL_CMD = kpackagetool6
CONFIG_FILE = ktogler-config.example.json
INSTALL_CONFIG = ktogler-config.json
INSTALL_DIR = $(HOME)/.local/share/kwin/scripts/$(SCRIPT_NAME)
CONFIG_GROUP = Script-$(SCRIPT_NAME)
CONFIG_KEY = config

# Source files
METADATA = metadata.json
MAIN_SCRIPT = contents/code/main.js
VERSION_FILE = VERSION
README = README.md
LICENSE = LICENSE

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: all build clean install uninstall purge reinstall enable disable reload check help config-sync config-push config-edit check-version clean-stale-shortcuts

# Default target
all: build

help:
	@echo "$(GREEN)ktogler Build System$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  $(YELLOW)build$(NC)        - Build the .kwinscript package"
	@echo "  $(YELLOW)check-version$(NC)- Verify VERSION and metadata.json are in sync"
	@echo "  $(YELLOW)install$(NC)      - Install the script"
	@echo "  $(YELLOW)uninstall$(NC)    - Uninstall the script"
	@echo "  $(YELLOW)purge$(NC)        - Uninstall and remove user config (destructive)"
	@echo "  $(YELLOW)reinstall$(NC)    - Uninstall and install (full refresh)"
	@echo "  $(YELLOW)enable$(NC)       - Enable the script"
	@echo "  $(YELLOW)disable$(NC)      - Disable the script"
	@echo "  $(YELLOW)reload$(NC)       - Reload KWin configuration"
	@echo "  $(YELLOW)check$(NC)        - Check if script is loaded"
	@echo "  $(YELLOW)clean$(NC)        - Remove build artifacts"
	@echo "  $(YELLOW)dev$(NC)          - Quick development cycle (reinstall + enable + reload + sync)"
	@echo ""
	@echo "$(BLUE)Configuration:$(NC)"
	@echo "  $(YELLOW)config-sync$(NC)  - Seed kwinrc config from example (if unset)"
	@echo "  $(YELLOW)config-push$(NC)  - Force-push installed config into kwinrc"
	@echo "  $(YELLOW)config-edit$(NC)  - Edit configuration file"
	@echo "  $(YELLOW)config-show$(NC)  - Show current configuration"
	@echo ""
	@echo "Current version: $(GREEN)$(VERSION)$(NC)"

# Verify VERSION and metadata.json are in sync
check-version:
	@test "$$(cat $(VERSION_FILE))" = "$$(sed -n 's/.*"Version": "\([^"]*\)".*/\1/p' $(METADATA))" \
		&& echo "$(GREEN)✓ Version in sync: $(VERSION)$(NC)" \
		|| (echo "$(RED)✗ Version mismatch: VERSION=$(shell cat VERSION), metadata.json=$(shell sed -n 's/.*"Version": "\([^"]*\)".*/\1/p' metadata.json)$(NC)" && exit 1)

# Build the package
build: clean check-version
	@echo "$(GREEN)Building $(PACKAGE_NAME)...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@zip -r $(BUILD_DIR)/$(PACKAGE_NAME) \
		$(METADATA) \
		contents \
		$(README) \
		$(LICENSE) \
		$(CONFIG_FILE) \
		-x "*.git*" "*/notes/*" "*/build/*"
	@echo "$(GREEN)✓ Package created: $(BUILD_DIR)/$(PACKAGE_NAME)$(NC)"

# Install the script
install: build
	@echo "$(GREEN)Installing $(SCRIPT_NAME)...$(NC)"
	@$(INSTALL_CMD) --type KWin/Script --install $(BUILD_DIR)/$(PACKAGE_NAME) 2>/dev/null || \
		$(INSTALL_CMD) --type KWin/Script --upgrade $(BUILD_DIR)/$(PACKAGE_NAME)
	@echo "$(GREEN)✓ Installed successfully$(NC)"

# Uninstall the script, disable it, and remove its shortcuts
# (config files are left in place; use `purge` to remove them too)
uninstall:
	@echo "$(YELLOW)Uninstalling $(SCRIPT_NAME)...$(NC)"
	@echo "  • Disabling plugin"
	@-kwriteconfig6 --file kwinrc --group Plugins --key $(SCRIPT_NAME)Enabled false >/dev/null 2>&1
	@echo "  • Unloading script from KWin"
	@-qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript $(SCRIPT_NAME) >/dev/null 2>&1
	@echo "  • Removing registered shortcuts"
	@-for name in $$(qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.shortcutNames 2>/dev/null | grep -E '^$(SHORTCUT_PREFIX)'); do \
		qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister kwin "$$name" >/dev/null 2>&1; \
	done
	@-qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.cleanUp >/dev/null 2>&1
	@echo "  • Removing package"
	@$(INSTALL_CMD) --type KWin/Script --remove $(SCRIPT_NAME) >/dev/null 2>&1 || \
		echo "    script not installed or already removed"
	@echo "  • Reloading KWin"
	@-qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
	@echo "  • Pruning leftover shortcut entries"
	@-sed -i '/^$(SHORTCUT_PREFIX)[A-Za-z0-9]*=/d' "$$HOME/.config/kglobalshortcutsrc"
	@echo "$(GREEN)✓ Uninstalled$(NC)"

# Uninstall and also remove user config (destructive)
purge: uninstall
	@echo "$(YELLOW)Purging configuration...$(NC)"
	@kwriteconfig6 --file kwinrc --group $(CONFIG_GROUP) --key $(CONFIG_KEY) --delete 2>/dev/null || true
	@rm -rf "$$HOME/.config/ktogler" "$$HOME/.ktogler"
	@echo "$(GREEN)✓ Configuration removed$(NC)"

# Reinstall (clean install)
reinstall: uninstall install

# Enable the script
enable:
	@echo "$(GREEN)Enabling $(SCRIPT_NAME)...$(NC)"
	@kwriteconfig6 --file kwinrc --group Plugins --key $(SCRIPT_NAME)Enabled true
	@echo "$(GREEN)✓ Enabled$(NC)"

# Disable the script
disable:
	@echo "$(YELLOW)Disabling $(SCRIPT_NAME)...$(NC)"
	@kwriteconfig6 --file kwinrc --group Plugins --key $(SCRIPT_NAME)Enabled false
	@echo "$(GREEN)✓ Disabled$(NC)"

# Reload the script. A plain `reconfigure` does not re-evaluate an already
# loaded script, so unload it first. Afterwards remove shortcuts left behind
# by apps that were dropped from the config.
reload:
	@echo "$(GREEN)Reloading KWin...$(NC)"
	@-qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript $(SCRIPT_NAME) >/dev/null 2>&1
	@qdbus6 org.kde.KWin /KWin reconfigure
	@sleep 1
	@$(MAKE) --no-print-directory clean-stale-shortcuts
	@echo "$(GREEN)✓ KWin reloaded$(NC)"

# Remove Ktogler* global shortcuts that are not part of the current config.
# KWin keeps actions for removed apps alive (with an empty key) in the live
# component and in kglobalshortcutsrc after a reload; deregister those so they
# don't linger in System Settings. Requires jq; skipped with a warning if
# unavailable.
clean-stale-shortcuts:
	@cfg=$$(kreadconfig6 --file kwinrc --group $(CONFIG_GROUP) --key $(CONFIG_KEY) 2>/dev/null); \
	if [ -z "$$cfg" ]; then \
		expected=""; \
	elif ! echo "$$cfg" | jq -r '.apps | keys[]' >/dev/null 2>&1; then \
		echo "  $(YELLOW)jq not available; skipping stale shortcut cleanup (install jq)$(NC)"; \
		expected=""; skip=1; \
	else \
		expected="$$(echo "$$cfg" | jq -r '.apps | keys[]' 2>/dev/null | while read -r n; do printf 'Ktogler%s\n' "$$(printf '%s' "$$n" | sed 's/^./\U&/')"; done)"; \
	fi; \
	if [ "$$skip" != "1" ]; then \
		for name in $$(qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.shortcutNames 2>/dev/null | grep -E '^$(SHORTCUT_PREFIX)'); do \
			if ! printf '%s\n' $$expected | grep -qx "$$name"; then \
				qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister kwin "$$name" >/dev/null 2>&1; \
				echo "  $(YELLOW)✓ Removed stale shortcut: $$name$(NC)"; \
			fi; \
		done; \
	fi

# Check if script is loaded and shortcuts are registered
check:
	@echo "$(GREEN)Checking script status...$(NC)"
	@echo ""
	@echo "Registered shortcuts:"
	@qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.shortcutNames 2>/dev/null | grep -E '^$(SHORTCUT_PREFIX)' || echo "  $(RED)No shortcuts found$(NC)"
	@echo ""
	@echo "Script loaded:"
	@qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded $(SCRIPT_NAME) 2>/dev/null | grep -q true && echo "  $(GREEN)✓ Loaded$(NC)" || echo "  $(RED)✗ Not loaded$(NC)"
	@echo ""
	@echo "Plugin status:"
	@kreadconfig6 --file kwinrc --group Plugins --key $(SCRIPT_NAME)Enabled | \
		grep -q "true" && echo "  $(GREEN)✓ Enabled$(NC)" || echo "  $(RED)✗ Disabled$(NC)"
	@echo ""
	@echo "kwinrc config ([$(CONFIG_GROUP)]/$(CONFIG_KEY)):"
	@kreadconfig6 --file kwinrc --group $(CONFIG_GROUP) --key $(CONFIG_KEY) 2>/dev/null | grep -q . && echo "  $(GREEN)✓ Set$(NC)" || echo "  $(YELLOW)⚠ Not set (no shortcuts registered)$(NC)"
	@echo ""
	@echo "Shortcut entries persisted in kglobalshortcutsrc:"
	@live=$$(qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.shortcutNames 2>/dev/null | grep -cE '^$(SHORTCUT_PREFIX)' || echo 0); \
	stored=$$(grep -cE '^$(SHORTCUT_PREFIX)[A-Za-z0-9]*=' "$$HOME/.config/kglobalshortcutsrc" 2>/dev/null || echo 0); \
	if [ "$$live" -gt 0 ]; then echo "  $(GREEN)✓ Present, in sync with live shortcuts$(NC)"; \
	elif [ "$$stored" -gt 0 ]; then echo "  $(RED)✗ Present but orphaned (nothing registered)$(NC)"; \
	else echo "  $(GREEN)✓ None$(NC)"; fi

# Seed config into kwinrc (Script group) and the installed JSON, if not already set
config-sync:
	@if [ -z "$$(kreadconfig6 --file kwinrc --group $(CONFIG_GROUP) --key $(CONFIG_KEY) 2>/dev/null)" ]; then \
		echo "$(GREEN)Seeding config into kwinrc [$(CONFIG_GROUP)]...$(NC)"; \
		kwriteconfig6 --file kwinrc --group $(CONFIG_GROUP) --key $(CONFIG_KEY) "$$(tr -d '\n' < $(CONFIG_FILE))"; \
		echo "$(GREEN)✓ Seeded: $(CONFIG_GROUP)/$(CONFIG_KEY)$(NC)"; \
	else \
		echo "$(YELLOW)! kwinrc config already set, keeping it: $(CONFIG_GROUP)/$(CONFIG_KEY)$(NC)"; \
	fi
	@if [ ! -f $(INSTALL_DIR)/$(INSTALL_CONFIG) ]; then \
		mkdir -p $(INSTALL_DIR); \
		cp $(CONFIG_FILE) $(INSTALL_DIR)/$(INSTALL_CONFIG); \
		echo "$(GREEN)✓ Seeded: $(INSTALL_DIR)/$(INSTALL_CONFIG)$(NC)"; \
	else \
		echo "$(YELLOW)! Installed config already exists, keeping it:$(NC)"; \
	fi

# Force-push the installed config file into kwinrc (overwrites)
config-push:
	@SRC="$(INSTALL_DIR)/$(INSTALL_CONFIG)"; [ -f "$$SRC" ] || SRC="$(CONFIG_FILE)"; \
	echo "$(GREEN)Pushing $$SRC -> kwinrc [$(CONFIG_GROUP)]...$(NC)"; \
	kwriteconfig6 --file kwinrc --group $(CONFIG_GROUP) --key $(CONFIG_KEY) "$$(tr -d '\n' < "$$SRC")"; \
	echo "$(GREEN)✓ Pushed$(NC)"

# Edit configuration (then push into kwinrc)
config-edit:
	@test -f $(INSTALL_DIR)/$(INSTALL_CONFIG) || (mkdir -p $(INSTALL_DIR) && cp $(CONFIG_FILE) $(INSTALL_DIR)/$(INSTALL_CONFIG))
	@$(EDITOR) $(INSTALL_DIR)/$(INSTALL_CONFIG)
	@echo ""
	@echo "$(GREEN)Pushing edited config into kwinrc...$(NC)"
	@kwriteconfig6 --file kwinrc --group $(CONFIG_GROUP) --key $(CONFIG_KEY) "$$(tr -d '\n' < $(INSTALL_DIR)/$(INSTALL_CONFIG))"
	@echo "$(YELLOW)Don't forget to reload KWin: make reload$(NC)"

# Show current configuration
config-show:
	@echo "$(GREEN)Current Configuration (kwinrc [$(CONFIG_GROUP)]/$(CONFIG_KEY)):$(NC)"
	@echo ""
	@val="$$(kreadconfig6 --file kwinrc --group $(CONFIG_GROUP) --key $(CONFIG_KEY) 2>/dev/null)"; \
	if [ -n "$$val" ]; then printf '%s\n' "$$val" | jq . 2>/dev/null || printf '%s\n' "$$val"; else echo "$(YELLOW)No config set in kwinrc$(NC)"; fi
	@echo ""
	@echo "$(GREEN)Installed JSON ($(INSTALL_DIR)/$(INSTALL_CONFIG)):$(NC)"
	@test -f $(INSTALL_DIR)/$(INSTALL_CONFIG) && cat $(INSTALL_DIR)/$(INSTALL_CONFIG) || echo "$(YELLOW)Not found (using example)$(NC)"

# Development cycle: quick reinstall and reload with config sync
dev: reinstall enable config-sync reload
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════$(NC)"
	@echo "$(GREEN)Development deployment complete!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  • Edit config: $(YELLOW)make config-edit$(NC) or $(YELLOW)./ktogler.sh edit$(NC)"
	@echo "  • Reload KWin: $(YELLOW)make reload$(NC) or $(YELLOW)./ktogler.sh reload$(NC)"
	@echo "  • Check logs:  $(YELLOW)journalctl --user -f | grep -i ktogler$(NC)"

# Clean build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@echo "$(GREEN)✓ Clean$(NC)"

# Version bump helpers
bump-major:
	@echo "$(GREEN)Bumping major version...$(NC)"
	@./scripts/bump-version.sh major

bump-minor:
	@echo "$(GREEN)Bumping minor version...$(NC)"
	@./scripts/bump-version.sh minor

bump-patch:
	@echo "$(GREEN)Bumping patch version...$(NC)"
	@./scripts/bump-version.sh patch
