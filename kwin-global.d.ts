// kwin-global.d.ts

/* File I/O function (may or may not be available in KWin environment) */
declare function readFile(path: string): string | undefined;

/* KConfig access: reads a key from the script's own group in kwinrc.
 * KWin runs the script under the config group "Script-<pluginId>". */
declare function readConfig(key: string, defaultValue?: string): string;

/* D-Bus bridge (present in KWin scripting, but returns values inconsistently
 * across builds; treat the result as untyped) */
declare function callDBus(
  service: string,
  path: string,
  iface: string,
  method: string,
  ...args: any[]
): any;

/* Environment access, if the runtime exposes it */
declare var getenv: ((name: string) => string) | undefined;

/* KWin globals */
interface KWinWindow {
  minimized: boolean;
  resourceClass: string;
}

declare const workspace: {
  windowList(): KWinWindow[];
  activeWindow: KWinWindow | null;
};

declare function registerShortcut(
  id: string,
  description: string,
  shortcut: string,
  callback: () => void
): void;

/* Console */
declare const console: {
  log(...args: any[]): void;
  warn(...args: any[]): void;
  error(...args: any[]): void;
};
