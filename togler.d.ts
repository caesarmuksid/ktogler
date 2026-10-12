// Togler domain types (ambient / global; no imports or exports)

/**
 * Configuration for the Togler script, stored as JSON in kwinrc under
 * [Script-togler]/config.
 *
 * - `apps` maps a logical app name to its window `resourceClass`.
 * - `shortcuts` maps the same app name to a shortcut (e.g. "Meta+K").
 *   Only apps present in both maps are registered.
 */
interface ToglerConfig {
  apps: Record<string, string>;
  shortcuts: Record<string, string>;
}
