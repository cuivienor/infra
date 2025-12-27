//! Project discovery module for zesh
//!
//! Discovers git repositories across configured roots, including support for
//! git worktrees and sparse checkouts.

// TODO: Remove when picker.rs integrates with discovery
#![allow(dead_code)]

use crate::config::{Config, Root};
use ignore::WalkBuilder;
use std::collections::HashMap;
use std::path::PathBuf;

/// A discovered project ready for session management
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Project {
    /// Display name for picker (basename, or parent/basename if collision)
    pub name: String,
    /// Absolute path to open in session
    pub path: PathBuf,
    /// Git repository root (may differ from path for worktrees/sparse)
    pub repo_root: PathBuf,
    /// If this is a worktree, which branch it tracks
    pub worktree_branch: Option<String>,
    /// If this is a sparse checkout, the zone path
    pub sparse_zone: Option<String>,
}

/// Discover all projects from configured roots
///
/// Walks each root directory up to its configured depth, finding git repositories.
/// For Phase 1, focuses on regular git repo discovery. Worktree and sparse checkout
/// support are stubbed for Phase 2.
pub fn discover_projects(config: &Config) -> Vec<Project> {
    let mut projects = Vec::new();

    for root in &config.roots {
        discover_from_root(root, &mut projects);
    }

    // Handle name collisions by adding parent directory
    resolve_name_collisions(&mut projects);

    projects
}

/// Discover projects from a single root
fn discover_from_root(root: &Root, projects: &mut Vec<Project>) {
    let root_path = root.expanded_path();

    if !root_path.exists() {
        return;
    }

    // Track which directories we've already identified as git repos
    // so we don't descend into them
    let mut found_repos: Vec<PathBuf> = Vec::new();

    // Use ignore crate's WalkBuilder for fast directory walking
    // We look for directories that contain a .git subdirectory
    let walker = WalkBuilder::new(&root_path)
        .max_depth(Some(root.depth as usize + 1)) // +1 because we need to see .git inside
        .hidden(false) // Don't skip hidden directories
        .git_ignore(false) // Don't respect .gitignore for discovery
        .git_global(false)
        .git_exclude(false)
        .sort_by_file_path(|a, b| a.cmp(b)) // Ensure deterministic order
        .build();

    for entry in walker.flatten() {
        let path = entry.path();

        // Skip if we're inside an already-found repo
        if found_repos.iter().any(|repo| path.starts_with(repo)) {
            continue;
        }

        // We're looking for .git directories (or files for worktrees)
        if path.file_name().is_some_and(|name| name == ".git") {
            if let Some(parent) = path.parent() {
                // Compute depth relative to root
                let depth = parent
                    .strip_prefix(&root_path)
                    .map(|rel| rel.components().count())
                    .unwrap_or(0);

                // Only include if within configured depth
                if depth <= root.depth as usize && depth > 0 {
                    let name = parent
                        .file_name()
                        .map(|s| s.to_string_lossy().to_string())
                        .unwrap_or_default();

                    let project = Project {
                        name,
                        path: parent.to_path_buf(),
                        repo_root: parent.to_path_buf(),
                        worktree_branch: None, // Phase 2
                        sparse_zone: None,     // Phase 2
                    };
                    projects.push(project);
                    found_repos.push(parent.to_path_buf());
                }
            }
        }
    }
}

/// Resolve name collisions by adding parent directory prefix
fn resolve_name_collisions(projects: &mut [Project]) {
    // Count occurrences of each name
    let mut name_counts: HashMap<String, usize> = HashMap::new();
    for project in projects.iter() {
        *name_counts.entry(project.name.clone()).or_insert(0) += 1;
    }

    // For collisions, prepend parent directory
    for project in projects.iter_mut() {
        if name_counts
            .get(&project.name)
            .is_some_and(|&count| count > 1)
        {
            if let Some(parent) = project.path.parent() {
                if let Some(parent_name) = parent.file_name() {
                    project.name = format!("{}/{}", parent_name.to_string_lossy(), project.name);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::Root;
    use std::fs;
    use std::process::Command;
    use tempfile::TempDir;

    /// Helper to create a git repo at a path
    fn create_git_repo(path: &std::path::Path) {
        fs::create_dir_all(path).unwrap();
        Command::new("git")
            .args(["init", "--initial-branch=main"])
            .current_dir(path)
            .output()
            .expect("Failed to init git repo");
    }

    // =========================================================================
    // Project struct tests
    // =========================================================================

    #[test]
    fn test_project_struct_has_required_fields() {
        let project = Project {
            name: "my-project".to_string(),
            path: PathBuf::from("/home/user/dev/my-project"),
            repo_root: PathBuf::from("/home/user/dev/my-project"),
            worktree_branch: None,
            sparse_zone: None,
        };

        assert_eq!(project.name, "my-project");
        assert_eq!(project.path, PathBuf::from("/home/user/dev/my-project"));
        assert_eq!(
            project.repo_root,
            PathBuf::from("/home/user/dev/my-project")
        );
        assert!(project.worktree_branch.is_none());
        assert!(project.sparse_zone.is_none());
    }

    #[test]
    fn test_project_with_worktree_branch() {
        let project = Project {
            name: "repo/feature-x".to_string(),
            path: PathBuf::from("/home/user/dev/repo-feature-x"),
            repo_root: PathBuf::from("/home/user/dev/repo"),
            worktree_branch: Some("feature-x".to_string()),
            sparse_zone: None,
        };

        assert_eq!(project.worktree_branch, Some("feature-x".to_string()));
    }

    #[test]
    fn test_project_with_sparse_zone() {
        let project = Project {
            name: "core/shopify".to_string(),
            path: PathBuf::from("/home/user/world/areas/core/shopify"),
            repo_root: PathBuf::from("/home/user/world"),
            worktree_branch: None,
            sparse_zone: Some("areas/core/shopify".to_string()),
        };

        assert_eq!(project.sparse_zone, Some("areas/core/shopify".to_string()));
    }

    #[test]
    fn test_project_equality() {
        let p1 = Project {
            name: "test".to_string(),
            path: PathBuf::from("/test"),
            repo_root: PathBuf::from("/test"),
            worktree_branch: None,
            sparse_zone: None,
        };
        let p2 = p1.clone();
        assert_eq!(p1, p2);
    }

    // =========================================================================
    // Discovery tests - empty/no config
    // =========================================================================

    #[test]
    fn test_discover_with_empty_config_returns_empty() {
        let config = Config::default();
        let projects = discover_projects(&config);
        assert!(projects.is_empty());
    }

    // =========================================================================
    // Discovery tests - regular git repos
    // =========================================================================

    #[test]
    fn test_discover_finds_git_repo_at_depth_1() {
        let temp = TempDir::new().unwrap();
        let project_path = temp.path().join("my-project");
        create_git_repo(&project_path);

        let config = Config {
            roots: vec![Root {
                path: temp.path().to_string_lossy().to_string(),
                depth: 1,
                sparse_checkout: false,
            }],
        };

        let projects = discover_projects(&config);

        assert_eq!(projects.len(), 1);
        assert_eq!(projects[0].name, "my-project");
        assert_eq!(projects[0].path, project_path);
        assert_eq!(projects[0].repo_root, project_path);
        assert!(projects[0].worktree_branch.is_none());
        assert!(projects[0].sparse_zone.is_none());
    }

    #[test]
    fn test_discover_finds_multiple_repos() {
        let temp = TempDir::new().unwrap();
        let project1 = temp.path().join("project-a");
        let project2 = temp.path().join("project-b");
        let project3 = temp.path().join("project-c");

        create_git_repo(&project1);
        create_git_repo(&project2);
        create_git_repo(&project3);

        let config = Config {
            roots: vec![Root {
                path: temp.path().to_string_lossy().to_string(),
                depth: 1,
                sparse_checkout: false,
            }],
        };

        let projects = discover_projects(&config);

        assert_eq!(projects.len(), 3);
        let names: Vec<_> = projects.iter().map(|p| p.name.as_str()).collect();
        assert!(names.contains(&"project-a"));
        assert!(names.contains(&"project-b"));
        assert!(names.contains(&"project-c"));
    }

    #[test]
    fn test_discover_finds_repo_at_depth_2() {
        let temp = TempDir::new().unwrap();
        let nested_project = temp.path().join("org").join("my-repo");
        create_git_repo(&nested_project);

        let config = Config {
            roots: vec![Root {
                path: temp.path().to_string_lossy().to_string(),
                depth: 2,
                sparse_checkout: false,
            }],
        };

        let projects = discover_projects(&config);

        assert_eq!(projects.len(), 1);
        assert_eq!(projects[0].name, "my-repo");
        assert_eq!(projects[0].path, nested_project);
    }

    #[test]
    fn test_discover_respects_depth_limit() {
        let temp = TempDir::new().unwrap();
        let too_deep = temp.path().join("a").join("b").join("c").join("project");
        create_git_repo(&too_deep);

        let config = Config {
            roots: vec![Root {
                path: temp.path().to_string_lossy().to_string(),
                depth: 2, // project is at depth 4, should not be found
                sparse_checkout: false,
            }],
        };

        let projects = discover_projects(&config);

        assert!(
            projects.is_empty(),
            "Should not find repo beyond depth limit"
        );
    }

    #[test]
    fn test_discover_does_not_descend_into_git_repos() {
        let temp = TempDir::new().unwrap();

        // Create outer repo
        let outer = temp.path().join("outer-repo");
        create_git_repo(&outer);

        // Create nested repo inside it (should not be found)
        let nested = outer.join("subprojects").join("nested-repo");
        create_git_repo(&nested);

        let config = Config {
            roots: vec![Root {
                path: temp.path().to_string_lossy().to_string(),
                depth: 4, // High depth, but should stop at outer-repo
                sparse_checkout: false,
            }],
        };

        let projects = discover_projects(&config);

        assert_eq!(projects.len(), 1);
        assert_eq!(projects[0].name, "outer-repo");
    }

    #[test]
    fn test_discover_from_multiple_roots() {
        let temp1 = TempDir::new().unwrap();
        let temp2 = TempDir::new().unwrap();

        let project1 = temp1.path().join("from-root1");
        let project2 = temp2.path().join("from-root2");

        create_git_repo(&project1);
        create_git_repo(&project2);

        let config = Config {
            roots: vec![
                Root {
                    path: temp1.path().to_string_lossy().to_string(),
                    depth: 1,
                    sparse_checkout: false,
                },
                Root {
                    path: temp2.path().to_string_lossy().to_string(),
                    depth: 1,
                    sparse_checkout: false,
                },
            ],
        };

        let projects = discover_projects(&config);

        assert_eq!(projects.len(), 2);
        let names: Vec<_> = projects.iter().map(|p| p.name.as_str()).collect();
        assert!(names.contains(&"from-root1"));
        assert!(names.contains(&"from-root2"));
    }

    #[test]
    fn test_discover_ignores_non_git_directories() {
        let temp = TempDir::new().unwrap();

        // Create a git repo
        let git_project = temp.path().join("git-project");
        create_git_repo(&git_project);

        // Create a regular directory (not a git repo)
        let regular_dir = temp.path().join("regular-dir");
        fs::create_dir_all(&regular_dir).unwrap();
        fs::write(regular_dir.join("file.txt"), "content").unwrap();

        let config = Config {
            roots: vec![Root {
                path: temp.path().to_string_lossy().to_string(),
                depth: 1,
                sparse_checkout: false,
            }],
        };

        let projects = discover_projects(&config);

        assert_eq!(projects.len(), 1);
        assert_eq!(projects[0].name, "git-project");
    }

    #[test]
    fn test_discover_handles_nonexistent_root_gracefully() {
        let config = Config {
            roots: vec![Root {
                path: "/nonexistent/path/that/does/not/exist".to_string(),
                depth: 2,
                sparse_checkout: false,
            }],
        };

        // Should not panic, just return empty
        let projects = discover_projects(&config);
        assert!(projects.is_empty());
    }

    #[test]
    fn test_discover_returns_absolute_paths() {
        let temp = TempDir::new().unwrap();
        let project_path = temp.path().join("project");
        create_git_repo(&project_path);

        let config = Config {
            roots: vec![Root {
                path: temp.path().to_string_lossy().to_string(),
                depth: 1,
                sparse_checkout: false,
            }],
        };

        let projects = discover_projects(&config);

        assert_eq!(projects.len(), 1);
        assert!(projects[0].path.is_absolute());
        assert!(projects[0].repo_root.is_absolute());
    }

    // =========================================================================
    // Name collision handling tests
    // =========================================================================

    #[test]
    fn test_discover_handles_name_collision_with_parent() {
        let temp = TempDir::new().unwrap();

        // Two repos with the same basename but different parents
        let project1 = temp.path().join("org-a").join("api");
        let project2 = temp.path().join("org-b").join("api");

        create_git_repo(&project1);
        create_git_repo(&project2);

        let config = Config {
            roots: vec![Root {
                path: temp.path().to_string_lossy().to_string(),
                depth: 2,
                sparse_checkout: false,
            }],
        };

        let projects = discover_projects(&config);

        assert_eq!(projects.len(), 2);

        // Names should include parent to disambiguate
        let names: Vec<_> = projects.iter().map(|p| p.name.as_str()).collect();
        assert!(
            names.contains(&"org-a/api") || names.contains(&"org-b/api"),
            "Should disambiguate with parent dir. Got: {:?}",
            names
        );
    }

    // =========================================================================
    // Worktree tests (Phase 1: basic stub, Phase 2: full support)
    // =========================================================================

    // These tests document expected behavior for Phase 2
    // For Phase 1, worktree detection can be stubbed

    #[test]
    #[ignore = "Phase 2: Full worktree support"]
    fn test_discover_detects_git_worktrees() {
        // TODO: Phase 2 - detect worktrees via `git worktree list`
        // Each worktree should become its own Project with worktree_branch set
    }

    // =========================================================================
    // Sparse checkout tests (Phase 1: basic stub, Phase 2: full support)
    // =========================================================================

    #[test]
    #[ignore = "Phase 2: Full sparse checkout support"]
    fn test_discover_detects_sparse_checkout_zones() {
        // TODO: Phase 2 - detect sparse zones via `git sparse-checkout list`
        // Each zone should become its own Project with sparse_zone set
    }
}
