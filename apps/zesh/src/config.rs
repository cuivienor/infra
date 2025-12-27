//! Configuration module for zesh
//!
//! Loads config from `~/.config/zesh/config.toml` with sensible defaults
//! if the config file doesn't exist.

// TODO: Remove when discovery.rs integrates with config
#![allow(dead_code)]

use anyhow::Result;
use serde::Deserialize;
use std::path::{Path, PathBuf};

/// A search root directory with discovery settings
#[derive(Debug, Clone, Deserialize, PartialEq)]
pub struct Root {
    /// Path to the root directory (supports ~ expansion)
    pub path: String,
    /// Maximum depth to search for projects
    pub depth: u32,
    /// Whether this root contains sparse checkout repos
    #[serde(default)]
    pub sparse_checkout: bool,
}

/// Main configuration structure
#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct Config {
    /// List of root directories to search for projects
    #[serde(default)]
    pub roots: Vec<Root>,
}

impl Root {
    /// Expand the path (handles ~ expansion)
    pub fn expanded_path(&self) -> PathBuf {
        let expanded = shellexpand::tilde(&self.path);
        PathBuf::from(expanded.as_ref())
    }
}

impl Config {
    /// Load configuration from the default config path
    ///
    /// Returns default config if file doesn't exist.
    /// Returns error if file exists but is malformed.
    pub fn load() -> Result<Self> {
        let config_path = Self::config_path()?;
        Self::load_from_path(&config_path)
    }

    /// Get the default config file path
    pub fn config_path() -> Result<PathBuf> {
        let config_dir = dirs::config_dir()
            .ok_or_else(|| anyhow::anyhow!("Could not determine config directory"))?;
        Ok(config_dir.join("zesh").join("config.toml"))
    }

    /// Load configuration from a specific path
    ///
    /// Returns default config if file doesn't exist.
    /// Returns error if file exists but is malformed.
    pub fn load_from_path(path: &Path) -> Result<Self> {
        if !path.exists() {
            return Ok(Config::default());
        }

        let content = std::fs::read_to_string(path)?;
        Self::parse(&content)
    }

    /// Parse configuration from TOML string
    pub fn parse(content: &str) -> Result<Self> {
        let config: Config = toml::from_str(content)?;
        Ok(config)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn test_parse_minimal_config() {
        let toml = r#"
[[roots]]
path = "~/dev"
depth = 2
"#;
        let config = Config::parse(toml).unwrap();
        assert_eq!(config.roots.len(), 1);
        assert_eq!(config.roots[0].path, "~/dev");
        assert_eq!(config.roots[0].depth, 2);
        assert!(!config.roots[0].sparse_checkout);
    }

    #[test]
    fn test_parse_multiple_roots() {
        let toml = r#"
[[roots]]
path = "~/dev"
depth = 2

[[roots]]
path = "~/src"
depth = 3

[[roots]]
path = "~/world"
depth = 1
sparse_checkout = true
"#;
        let config = Config::parse(toml).unwrap();
        assert_eq!(config.roots.len(), 3);

        assert_eq!(config.roots[0].path, "~/dev");
        assert_eq!(config.roots[0].depth, 2);
        assert!(!config.roots[0].sparse_checkout);

        assert_eq!(config.roots[1].path, "~/src");
        assert_eq!(config.roots[1].depth, 3);
        assert!(!config.roots[1].sparse_checkout);

        assert_eq!(config.roots[2].path, "~/world");
        assert_eq!(config.roots[2].depth, 1);
        assert!(config.roots[2].sparse_checkout);
    }

    #[test]
    fn test_parse_empty_config() {
        let config = Config::parse("").unwrap();
        assert!(config.roots.is_empty());
    }

    #[test]
    fn test_parse_invalid_toml() {
        let toml = "this is not valid toml [[[";
        let result = Config::parse(toml);
        assert!(result.is_err());
    }

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert!(config.roots.is_empty());
    }

    #[test]
    fn test_load_from_nonexistent_path() {
        let path = PathBuf::from("/nonexistent/path/config.toml");
        let config = Config::load_from_path(&path).unwrap();
        assert!(config.roots.is_empty());
    }

    #[test]
    fn test_load_from_valid_file() {
        let mut file = NamedTempFile::new().unwrap();
        writeln!(
            file,
            r#"
[[roots]]
path = "~/projects"
depth = 3
"#
        )
        .unwrap();

        let config = Config::load_from_path(&file.path().to_path_buf()).unwrap();
        assert_eq!(config.roots.len(), 1);
        assert_eq!(config.roots[0].path, "~/projects");
        assert_eq!(config.roots[0].depth, 3);
    }

    #[test]
    fn test_load_from_malformed_file() {
        let mut file = NamedTempFile::new().unwrap();
        writeln!(file, "invalid toml [[[").unwrap();

        let result = Config::load_from_path(&file.path().to_path_buf());
        assert!(result.is_err());
    }

    #[test]
    fn test_expanded_path_tilde() {
        let root = Root {
            path: "~/dev".to_string(),
            depth: 2,
            sparse_checkout: false,
        };
        let expanded = root.expanded_path();
        // Should expand ~ to home directory
        assert!(!expanded.to_string_lossy().contains('~'));
        assert!(expanded.to_string_lossy().contains("dev"));
    }

    #[test]
    fn test_expanded_path_absolute() {
        let root = Root {
            path: "/absolute/path".to_string(),
            depth: 1,
            sparse_checkout: false,
        };
        let expanded = root.expanded_path();
        assert_eq!(expanded, PathBuf::from("/absolute/path"));
    }

    #[test]
    fn test_config_path_returns_xdg_location() {
        let path = Config::config_path().unwrap();
        // Should be in some config directory ending with zesh/config.toml
        let path_str = path.to_string_lossy();
        assert!(path_str.ends_with("zesh/config.toml"));
    }

    #[test]
    fn test_sparse_checkout_defaults_to_false() {
        let toml = r#"
[[roots]]
path = "~/code"
depth = 1
"#;
        let config = Config::parse(toml).unwrap();
        assert!(!config.roots[0].sparse_checkout);
    }
}
