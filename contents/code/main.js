/*
 * Load configuration. Preference order:
 *
 *   1) KConfig: the kwinrc group [Script-<pluginId>], key "config" (a JSON
 *      blob). Managed with `make config-sync` / `togler.sh sync`, or directly:
 *        kwriteconfig6 --file kwinrc --group Script-togler --key config '<json>'
 *   2) A JSON file via readFile (fallback for builds where readConfig is
 *      missing or the kwinrc key is empty).
 *
 * If no config is found, no shortcuts are registered. Use the packaged
 * togler-config.example.json as a template.
 */
/** @returns {ToglerConfig} */
function emptyConfig() {
  return { apps: {}, shortcuts: {} };
}

/**
 * Validate a parsed value as a ToglerConfig.
 * @param {unknown} cfg
 * @returns {ToglerConfig | null}
 */
function toConfig(cfg) {
  if (!cfg || typeof cfg !== "object") {
    return null;
  }
  const candidate = /** @type {{ apps?: unknown, shortcuts?: unknown }} */ (
    cfg
  );
  if (
    candidate.apps &&
    typeof candidate.apps === "object" &&
    candidate.shortcuts &&
    typeof candidate.shortcuts === "object"
  ) {
    return {
      apps: /** @type {Record<string, string>} */ (candidate.apps),
      shortcuts: /** @type {Record<string, string>} */ (candidate.shortcuts),
    };
  }
  return null;
}

/** @returns {ToglerConfig} */
function loadConfig() {
  // 1) KConfig: kwinrc -> [Script-<id>] -> "config" key
  if (typeof readConfig === "function") {
    try {
      const raw = readConfig("config", "");
      if (raw) {
        const cfg = toConfig(JSON.parse(raw));
        if (cfg) {
          return cfg;
        }
        console.warn("kwinrc config key is not a valid config; ignoring");
      }
    } catch (e) {
      console.error("Failed to parse kwinrc config:", e);
    }
  }

  // 2) JSON file fallback for builds that support readFile
  if (typeof readFile === "function") {
    /**
     * @param {string} path
     * @returns {ToglerConfig | null}
     */
    function tryReadJson(path) {
      try {
        const content = readFile(path);
        if (content) {
          const cfg = toConfig(JSON.parse(content));
          if (cfg) {
            return cfg;
          }
        }
      } catch (e) {
        console.error("Failed to read/parse", path, ":", e);
      }
      return null;
    }

    /** @type {string[]} */
    const candidates = [];

    if (typeof getenv === "function") {
      const xdg = getenv("XDG_CONFIG_HOME");
      const home = getenv("HOME");
      if (xdg) {
        candidates.push(xdg + "/kwin-togler/config.json");
      }
      if (home) {
        candidates.push(home + "/.config/kwin-togler/config.json");
        candidates.push(home + "/.kwin-togler/config.json");
      }
    }
    /*
     * If `getenv` is unavailable, no XDG/HOME candidate is added; a config
     * can still be supplied at the installed location below.
     */
    // Config installed alongside the script by the tooling
    candidates.push("../../togler-config.json");

    for (let i = 0; i < candidates.length; i++) {
      const cfg = tryReadJson(candidates[i]);
      if (cfg) return cfg;
    }
  }

  console.warn(
    "No configuration found. Run `make config-sync` or `togler.sh edit` " +
      "(stored in kwinrc under Script-togler); no shortcuts registered."
  );
  return emptyConfig();
}

/** @param {KWinWindow} win */
function focusWindow(win) {
  if (win.minimized) {
    win.minimized = false;
  }
  workspace.activeWindow = win;
}

/**
 * Toggle visibility/focus of an application, cycling through all
 * open instances (windows sharing the same resourceClass).
 *
 * Behavior:
 *  - No window of this app active anywhere -> focus the first instance.
 *  - One of this app's windows is active -> focus the NEXT instance.
 *  - The LAST instance is active (cycle complete) -> minimize ALL instances.
 *
 * With a single matching window this degenerates exactly to the original
 * bring-to-front / minimize toggle behavior.
 *
 * @param {string} appName
 * @param {string} resourceClass
 */
function toggleWindow(appName, resourceClass) {
  if (!resourceClass) {
    console.warn("Unknown app:", appName);
    return;
  }

  const clients = workspace.windowList();
  /** @type {KWinWindow[]} */
  const matches = [];

  for (let i = 0; i < clients.length; i++) {
    if (clients[i].resourceClass === resourceClass) {
      matches.push(clients[i]);
    }
  }

  if (matches.length === 0) {
    return;
  }

  const active = workspace.activeWindow;
  const activeIndex = active === null ? -1 : matches.indexOf(active);

  if (activeIndex === -1) {
    // No window of this app is active -> focus the first instance
    focusWindow(matches[0]);
  } else if (activeIndex < matches.length - 1) {
    // Cycle to the next instance
    const nextIndex = activeIndex + 1;
    focusWindow(matches[nextIndex]);
  } else {
    // Last instance active -> cycle complete, minimize all instances
    for (let i = 0; i < matches.length; i++) {
      matches[i].minimized = true;
    }
  }
}

// Load configuration
const config = loadConfig();

// Register shortcuts dynamically based on config
for (const appName in config.apps) {
  const resourceClass = config.apps[appName];
  const shortcut = config.shortcuts[appName];

  if (shortcut) {
    const shortcutId =
      "Togler" + appName.charAt(0).toUpperCase() + appName.slice(1);
    const description =
      "Toggle " + appName.charAt(0).toUpperCase() + appName.slice(1);

    try {
      // Create closure to capture the current values
      (function (name, resClass) {
        registerShortcut(shortcutId, description, shortcut, function () {
          toggleWindow(name, resClass);
        });
      })(appName, resourceClass);
    } catch (e) {
      console.error("Failed to register shortcut for", appName, ":", e);
    }
  }
}
