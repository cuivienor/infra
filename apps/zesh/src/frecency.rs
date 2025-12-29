//! Frecency tracking module for zesh
//!
//! Tracks project access frequency and recency to sort projects by usage patterns.
//! Data is persisted to `~/.local/share/zesh/frecency.json`.

use crate::discovery::Project;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

/// Entry for a single project's frecency data
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FrecencyEntry {
    /// Number of times this project has been accessed
    pub frequency: u32,
    /// Unix timestamp of last access
    pub last_access: u64,
}

/// Persistent store for frecency data
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct FrecencyStore {
    /// Map of project path (as string) to frecency entry
    entries: HashMap<String, FrecencyEntry>,
    /// Path to the data file (not serialized)
    #[serde(skip)]
    data_path: Option<PathBuf>,
}

impl FrecencyStore {
    /// Create a new FrecencyStore that will persist to the default data path
    ///
    /// The default path is `~/.local/share/zesh/frecency.json`
    pub fn new() -> Result<Self> {
        let data_path = Self::default_data_path()?;
        Ok(Self::with_path(data_path))
    }

    /// Create a FrecencyStore with a custom data path
    ///
    /// Loads existing data from the path if it exists.
    /// Creates an empty store if the file doesn't exist or is corrupt.
    #[must_use]
    pub fn with_path(path: PathBuf) -> Self {
        let mut store = if path.exists() {
            match fs::read_to_string(&path) {
                Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
                Err(_) => FrecencyStore::default(),
            }
        } else {
            FrecencyStore::default()
        };
        store.data_path = Some(path);
        store
    }

    /// Get the default data file path
    pub fn default_data_path() -> Result<PathBuf> {
        let data_dir = dirs::data_dir()
            .ok_or_else(|| anyhow::anyhow!("Could not determine data directory"))?;
        Ok(data_dir.join("zesh").join("frecency.json"))
    }

    /// Record an access to a project, updating frequency and last access time
    pub fn record_access(&mut self, path: &Path) -> Result<()> {
        let path_str = path.to_string_lossy().to_string();
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        let entry = self.entries.entry(path_str).or_insert(FrecencyEntry {
            frequency: 0,
            last_access: now,
        });
        entry.frequency += 1;
        entry.last_access = now;

        self.save()
    }

    /// Get the frecency score for a project path
    ///
    /// Score is calculated as: frequency * recency_weight
    /// where recency_weight decays by half every week (604800 seconds)
    pub fn get_score(&self, path: &Path) -> f64 {
        let path_str = path.to_string_lossy().to_string();

        match self.entries.get(&path_str) {
            Some(entry) => calculate_score(entry.frequency, entry.last_access),
            None => 0.0,
        }
    }

    /// Sort projects by frecency score (highest first)
    pub fn sort_by_frecency(&self, projects: &mut [Project]) {
        projects.sort_by(|a, b| {
            let score_a = self.get_score(&a.path);
            let score_b = self.get_score(&b.path);
            // Sort descending (highest score first)
            score_b
                .partial_cmp(&score_a)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
    }

    /// Save the store to disk
    fn save(&self) -> Result<()> {
        if let Some(ref path) = self.data_path {
            // Create parent directory if needed
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent)?;
            }
            let json = serde_json::to_string_pretty(self)?;
            fs::write(path, json)?;
        }
        Ok(())
    }

    /// Get an entry for testing purposes
    #[cfg(test)]
    pub fn get_entry(&self, path: &Path) -> Option<&FrecencyEntry> {
        let path_str = path.to_string_lossy().to_string();
        self.entries.get(&path_str)
    }
}

/// Calculate frecency score from frequency and last access time
///
/// Score = frequency * recency_weight
/// recency_weight decays by half every week (604800 seconds)
fn calculate_score(frequency: u32, last_access: u64) -> f64 {
    let now = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let age_secs = now.saturating_sub(last_access) as f64;

    // Decay by half every week (604800 seconds)
    let recency_weight = 0.5_f64.powf(age_secs / 604_800.0);

    frequency as f64 * recency_weight
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    // =========================================================================
    // FrecencyEntry tests
    // =========================================================================

    #[test]
    fn test_frecency_entry_has_required_fields() {
        let entry = FrecencyEntry {
            frequency: 5,
            last_access: 1700000000,
        };

        assert_eq!(entry.frequency, 5);
        assert_eq!(entry.last_access, 1700000000);
    }

    #[test]
    fn test_frecency_entry_serialization() {
        let entry = FrecencyEntry {
            frequency: 10,
            last_access: 1700000000,
        };

        let json = serde_json::to_string(&entry).unwrap();
        let deserialized: FrecencyEntry = serde_json::from_str(&json).unwrap();

        assert_eq!(entry, deserialized);
    }

    // =========================================================================
    // FrecencyStore creation tests
    // =========================================================================

    #[test]
    fn test_frecency_store_default_is_empty() {
        let store = FrecencyStore::default();
        assert!(store.entries.is_empty());
    }

    #[test]
    fn test_frecency_store_with_nonexistent_path_creates_empty() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("nonexistent").join("frecency.json");

        let store = FrecencyStore::with_path(data_path);
        assert!(store.entries.is_empty());
    }

    #[test]
    fn test_frecency_store_loads_existing_data() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");

        // Write some data manually
        let json = r#"{"entries":{"/test/path":{"frequency":5,"last_access":1700000000}}}"#;
        fs::write(&data_path, json).unwrap();

        let store = FrecencyStore::with_path(data_path);

        let entry = store.get_entry(Path::new("/test/path")).unwrap();
        assert_eq!(entry.frequency, 5);
        assert_eq!(entry.last_access, 1700000000);
    }

    #[test]
    fn test_frecency_store_handles_corrupt_file_gracefully() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");

        // Write invalid JSON
        fs::write(&data_path, "not valid json {{{{").unwrap();

        // Should return empty store, not error
        let store = FrecencyStore::with_path(data_path);
        assert!(store.entries.is_empty());
    }

    #[test]
    fn test_frecency_store_handles_empty_file_gracefully() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");

        fs::write(&data_path, "").unwrap();

        // Should return empty store, not error
        let store = FrecencyStore::with_path(data_path);
        assert!(store.entries.is_empty());
    }

    #[test]
    fn test_default_data_path_is_in_xdg_data() {
        let path = FrecencyStore::default_data_path().unwrap();
        let path_str = path.to_string_lossy();
        assert!(path_str.ends_with("zesh/frecency.json"));
    }

    // =========================================================================
    // record_access tests
    // =========================================================================

    #[test]
    fn test_record_access_creates_new_entry() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let mut store = FrecencyStore::with_path(data_path);

        let project_path = Path::new("/home/user/dev/project");
        store.record_access(project_path).unwrap();

        let entry = store.get_entry(project_path).unwrap();
        assert_eq!(entry.frequency, 1);
        assert!(entry.last_access > 0);
    }

    #[test]
    fn test_record_access_increments_frequency() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let mut store = FrecencyStore::with_path(data_path);

        let project_path = Path::new("/home/user/dev/project");

        store.record_access(project_path).unwrap();
        store.record_access(project_path).unwrap();
        store.record_access(project_path).unwrap();

        let entry = store.get_entry(project_path).unwrap();
        assert_eq!(entry.frequency, 3);
    }

    #[test]
    fn test_record_access_updates_last_access_time() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let mut store = FrecencyStore::with_path(data_path);

        let project_path = Path::new("/home/user/dev/project");

        store.record_access(project_path).unwrap();
        let first_access = store.get_entry(project_path).unwrap().last_access;

        // Small delay to ensure time changes
        std::thread::sleep(std::time::Duration::from_millis(10));

        store.record_access(project_path).unwrap();
        let second_access = store.get_entry(project_path).unwrap().last_access;

        // Last access should be updated (or at least not earlier)
        assert!(second_access >= first_access);
    }

    #[test]
    fn test_record_access_persists_to_disk() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");

        // Create store, record access, drop it
        {
            let mut store = FrecencyStore::with_path(data_path.clone());
            store.record_access(Path::new("/test/project")).unwrap();
        }

        // Load again and verify data persisted
        let store = FrecencyStore::with_path(data_path);
        let entry = store.get_entry(Path::new("/test/project")).unwrap();
        assert_eq!(entry.frequency, 1);
    }

    #[test]
    fn test_record_access_creates_parent_directories() {
        let temp = TempDir::new().unwrap();
        let data_path = temp
            .path()
            .join("nested")
            .join("dirs")
            .join("frecency.json");

        let mut store = FrecencyStore::with_path(data_path.clone());
        store.record_access(Path::new("/test/project")).unwrap();

        // Verify file was created
        assert!(data_path.exists());
    }

    // =========================================================================
    // get_score tests
    // =========================================================================

    #[test]
    fn test_get_score_returns_zero_for_unknown_path() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let store = FrecencyStore::with_path(data_path);

        let score = store.get_score(Path::new("/unknown/path"));
        assert_eq!(score, 0.0);
    }

    #[test]
    fn test_get_score_returns_positive_for_accessed_path() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let mut store = FrecencyStore::with_path(data_path);

        let project_path = Path::new("/test/project");
        store.record_access(project_path).unwrap();

        let score = store.get_score(project_path);
        assert!(score > 0.0);
    }

    #[test]
    fn test_get_score_higher_for_more_frequent_access() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let mut store = FrecencyStore::with_path(data_path);

        let path_once = Path::new("/accessed/once");
        let path_many = Path::new("/accessed/many");

        store.record_access(path_once).unwrap();

        store.record_access(path_many).unwrap();
        store.record_access(path_many).unwrap();
        store.record_access(path_many).unwrap();
        store.record_access(path_many).unwrap();
        store.record_access(path_many).unwrap();

        let score_once = store.get_score(path_once);
        let score_many = store.get_score(path_many);

        assert!(
            score_many > score_once,
            "More frequent access should have higher score"
        );
    }

    // =========================================================================
    // calculate_score tests (internal function)
    // =========================================================================

    #[test]
    fn test_calculate_score_recent_access_has_high_weight() {
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Very recent access (1 second ago)
        let score = calculate_score(10, now - 1);

        // Should be very close to frequency since recency_weight is ~1
        assert!(score > 9.9);
        assert!(score <= 10.0);
    }

    #[test]
    fn test_calculate_score_one_week_old_has_half_weight() {
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let one_week_ago = now - 604800; // Exactly one week

        let score = calculate_score(10, one_week_ago);

        // Should be approximately half of frequency
        assert!(
            (score - 5.0).abs() < 0.1,
            "Score {} should be close to 5.0",
            score
        );
    }

    #[test]
    fn test_calculate_score_two_weeks_old_has_quarter_weight() {
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let two_weeks_ago = now - (604800 * 2);

        let score = calculate_score(10, two_weeks_ago);

        // Should be approximately quarter of frequency
        assert!(
            (score - 2.5).abs() < 0.1,
            "Score {} should be close to 2.5",
            score
        );
    }

    #[test]
    fn test_calculate_score_zero_frequency_is_zero() {
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let score = calculate_score(0, now);
        assert_eq!(score, 0.0);
    }

    // =========================================================================
    // sort_by_frecency tests
    // =========================================================================

    #[test]
    fn test_sort_by_frecency_empty_list() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let store = FrecencyStore::with_path(data_path);

        let mut projects: Vec<Project> = vec![];
        store.sort_by_frecency(&mut projects);

        assert!(projects.is_empty());
    }

    #[test]
    fn test_sort_by_frecency_single_project() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let store = FrecencyStore::with_path(data_path);

        let mut projects = vec![Project {
            name: "single".to_string(),
            path: PathBuf::from("/test/single"),
            repo_root: PathBuf::from("/test/single"),
            worktree_branch: None,
            sparse_zone: None,
        }];

        store.sort_by_frecency(&mut projects);

        assert_eq!(projects.len(), 1);
        assert_eq!(projects[0].name, "single");
    }

    #[test]
    fn test_sort_by_frecency_orders_by_score_descending() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let mut store = FrecencyStore::with_path(data_path);

        // Create projects
        let mut projects = vec![
            Project {
                name: "low".to_string(),
                path: PathBuf::from("/test/low"),
                repo_root: PathBuf::from("/test/low"),
                worktree_branch: None,
                sparse_zone: None,
            },
            Project {
                name: "high".to_string(),
                path: PathBuf::from("/test/high"),
                repo_root: PathBuf::from("/test/high"),
                worktree_branch: None,
                sparse_zone: None,
            },
            Project {
                name: "medium".to_string(),
                path: PathBuf::from("/test/medium"),
                repo_root: PathBuf::from("/test/medium"),
                worktree_branch: None,
                sparse_zone: None,
            },
        ];

        // Record different frequencies (more = higher score)
        store.record_access(Path::new("/test/low")).unwrap();

        store.record_access(Path::new("/test/medium")).unwrap();
        store.record_access(Path::new("/test/medium")).unwrap();
        store.record_access(Path::new("/test/medium")).unwrap();

        store.record_access(Path::new("/test/high")).unwrap();
        store.record_access(Path::new("/test/high")).unwrap();
        store.record_access(Path::new("/test/high")).unwrap();
        store.record_access(Path::new("/test/high")).unwrap();
        store.record_access(Path::new("/test/high")).unwrap();

        store.sort_by_frecency(&mut projects);

        assert_eq!(projects[0].name, "high");
        assert_eq!(projects[1].name, "medium");
        assert_eq!(projects[2].name, "low");
    }

    #[test]
    fn test_sort_by_frecency_untracked_projects_go_to_end() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let mut store = FrecencyStore::with_path(data_path);

        let mut projects = vec![
            Project {
                name: "untracked".to_string(),
                path: PathBuf::from("/test/untracked"),
                repo_root: PathBuf::from("/test/untracked"),
                worktree_branch: None,
                sparse_zone: None,
            },
            Project {
                name: "tracked".to_string(),
                path: PathBuf::from("/test/tracked"),
                repo_root: PathBuf::from("/test/tracked"),
                worktree_branch: None,
                sparse_zone: None,
            },
        ];

        // Only record access for tracked
        store.record_access(Path::new("/test/tracked")).unwrap();

        store.sort_by_frecency(&mut projects);

        // Tracked should come first (higher score)
        assert_eq!(projects[0].name, "tracked");
        assert_eq!(projects[1].name, "untracked");
    }

    #[test]
    fn test_sort_by_frecency_preserves_projects() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let store = FrecencyStore::with_path(data_path);

        let original_projects = vec![
            Project {
                name: "a".to_string(),
                path: PathBuf::from("/test/a"),
                repo_root: PathBuf::from("/test/a"),
                worktree_branch: Some("feature".to_string()),
                sparse_zone: None,
            },
            Project {
                name: "b".to_string(),
                path: PathBuf::from("/test/b"),
                repo_root: PathBuf::from("/test/b"),
                worktree_branch: None,
                sparse_zone: Some("zone".to_string()),
            },
        ];

        let mut projects = original_projects.clone();
        store.sort_by_frecency(&mut projects);

        // All projects should still be present with all fields intact
        assert_eq!(projects.len(), 2);

        let a = projects.iter().find(|p| p.name == "a").unwrap();
        assert_eq!(a.worktree_branch, Some("feature".to_string()));

        let b = projects.iter().find(|p| p.name == "b").unwrap();
        assert_eq!(b.sparse_zone, Some("zone".to_string()));
    }

    // =========================================================================
    // Persistence round-trip tests
    // =========================================================================

    #[test]
    fn test_frecency_store_full_round_trip() {
        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");

        // Create store and record various accesses
        {
            let mut store = FrecencyStore::with_path(data_path.clone());
            store.record_access(Path::new("/project/a")).unwrap();
            store.record_access(Path::new("/project/a")).unwrap();
            store.record_access(Path::new("/project/b")).unwrap();
        }

        // Load fresh and verify
        {
            let store = FrecencyStore::with_path(data_path);

            let entry_a = store.get_entry(Path::new("/project/a")).unwrap();
            assert_eq!(entry_a.frequency, 2);

            let entry_b = store.get_entry(Path::new("/project/b")).unwrap();
            assert_eq!(entry_b.frequency, 1);

            // Scores should reflect frequency
            let score_a = store.get_score(Path::new("/project/a"));
            let score_b = store.get_score(Path::new("/project/b"));
            assert!(score_a > score_b);
        }
    }
}
