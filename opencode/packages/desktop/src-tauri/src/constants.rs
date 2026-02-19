#[cfg(not(target_os = "android"))]
use tauri_plugin_window_state::StateFlags;

#[cfg(not(target_os = "android"))]
pub const SETTINGS_STORE: &str = "opencode.settings.dat";
#[cfg(not(target_os = "android"))]
pub const DEFAULT_SERVER_URL_KEY: &str = "defaultServerUrl";
#[cfg(not(target_os = "android"))]
pub const WSL_ENABLED_KEY: &str = "wslEnabled";
pub const UPDATER_ENABLED: bool = option_env!("TAURI_SIGNING_PRIVATE_KEY").is_some();

#[cfg(not(target_os = "android"))]
pub fn window_state_flags() -> StateFlags {
    StateFlags::all() - StateFlags::DECORATIONS - StateFlags::VISIBLE
}
