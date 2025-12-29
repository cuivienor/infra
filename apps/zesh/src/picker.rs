//! Interactive picker module for zesh
//!
//! Provides fuzzy selection using skim for choosing projects.
//! Projects are sorted by frecency before display.

use crate::discovery::Project;
use crate::frecency::FrecencyStore;
use skim::prelude::*;
use std::sync::Arc;

/// A wrapper around Project that implements SkimItem for use in the picker
struct ProjectItem {
    project: Project,
}

impl SkimItem for ProjectItem {
    fn text(&self) -> Cow<'_, str> {
        Cow::Borrowed(&self.project.name)
    }
}

/// Pick a project from a list using interactive fuzzy selection
///
/// Projects are sorted by frecency before display (highest score first).
/// Returns None if the user cancels (Esc) or if no projects are provided.
///
/// # Arguments
/// * `projects` - Slice of projects to choose from
/// * `frecency` - Frecency store for sorting by usage
/// * `query` - Optional initial query string for fuzzy matching
pub fn pick_project(
    projects: &[Project],
    frecency: &FrecencyStore,
    query: Option<&str>,
) -> Option<Project> {
    if projects.is_empty() {
        return None;
    }

    // Sort by frecency (mutates a copy)
    let mut sorted_projects = projects.to_vec();
    frecency.sort_by_frecency(&mut sorted_projects);

    // Build skim options
    let mut options_builder = SkimOptionsBuilder::default();
    options_builder
        .height(Some("40%"))
        .reverse(true)
        .prompt(Some("project> "));

    // Set initial query if provided
    if let Some(q) = query {
        options_builder.query(Some(q));
    }

    let options = options_builder.build().unwrap();

    // Convert projects to skim items
    let (tx, rx): (SkimItemSender, SkimItemReceiver) = unbounded();

    for project in sorted_projects.iter() {
        let item = ProjectItem {
            project: project.clone(),
        };
        let _ = tx.send(Arc::new(item));
    }
    drop(tx); // Close sender so skim knows when items are done

    // Run the picker
    let output = Skim::run_with(&options, Some(rx))?;

    // Check if user pressed Escape or Ctrl-C
    if output.is_abort {
        return None;
    }

    // Get the selected item
    let selected = output.selected_items.first()?;

    // Downcast back to ProjectItem to get the project
    // The output text matches our project name, so find by name
    let selected_name = selected.output();
    sorted_projects
        .into_iter()
        .find(|p| p.name == selected_name.as_ref())
}

/// Fuzzy match projects and return single match or None
///
/// If exactly one project matches the query, returns it directly.
/// If multiple match, returns None (caller should use picker).
/// If none match, returns None.
pub fn fuzzy_match_single(projects: &[Project], query: &str) -> Option<Project> {
    let query_lower = query.to_lowercase();

    let matches: Vec<_> = projects
        .iter()
        .filter(|p| p.name.to_lowercase().contains(&query_lower))
        .collect();

    if matches.len() == 1 {
        Some(matches[0].clone())
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn make_project(name: &str) -> Project {
        Project {
            name: name.to_string(),
            path: PathBuf::from(format!("/test/{}", name)),
            repo_root: PathBuf::from(format!("/test/{}", name)),
            worktree_branch: None,
            sparse_zone: None,
        }
    }

    // =========================================================================
    // fuzzy_match_single tests
    // =========================================================================

    #[test]
    fn test_fuzzy_match_single_empty_projects() {
        let projects: Vec<Project> = vec![];
        let result = fuzzy_match_single(&projects, "test");
        assert!(result.is_none());
    }

    #[test]
    fn test_fuzzy_match_single_no_match() {
        let projects = vec![make_project("alpha"), make_project("beta")];
        let result = fuzzy_match_single(&projects, "xyz");
        assert!(result.is_none());
    }

    #[test]
    fn test_fuzzy_match_single_exact_match() {
        let projects = vec![
            make_project("infra"),
            make_project("website"),
            make_project("api"),
        ];
        let result = fuzzy_match_single(&projects, "infra");
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "infra");
    }

    #[test]
    fn test_fuzzy_match_single_partial_match() {
        let projects = vec![
            make_project("my-project"),
            make_project("other"),
            make_project("another"),
        ];
        let result = fuzzy_match_single(&projects, "proj");
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "my-project");
    }

    #[test]
    fn test_fuzzy_match_single_multiple_matches_returns_none() {
        let projects = vec![
            make_project("project-a"),
            make_project("project-b"),
            make_project("other"),
        ];
        // "project" matches both project-a and project-b
        let result = fuzzy_match_single(&projects, "project");
        assert!(result.is_none());
    }

    #[test]
    fn test_fuzzy_match_single_case_insensitive() {
        let projects = vec![make_project("MyProject"), make_project("other")];
        let result = fuzzy_match_single(&projects, "myproject");
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "MyProject");
    }

    #[test]
    fn test_fuzzy_match_single_with_path_like_name() {
        let projects = vec![
            make_project("org-a/api"),
            make_project("org-b/api"),
            make_project("org-a/web"),
        ];
        // "org-a/api" should uniquely match
        let result = fuzzy_match_single(&projects, "org-a/api");
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "org-a/api");
    }

    #[test]
    fn test_fuzzy_match_single_substring_in_path() {
        let projects = vec![make_project("org-a/api"), make_project("org-b/web")];
        // "a/api" should match "org-a/api"
        let result = fuzzy_match_single(&projects, "a/api");
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "org-a/api");
    }

    // =========================================================================
    // pick_project tests (unit tests for non-interactive parts)
    // The actual TUI interaction is tested manually
    // =========================================================================

    #[test]
    fn test_pick_project_empty_list_returns_none() {
        // This doesn't invoke skim, just returns early
        use tempfile::TempDir;

        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let frecency = FrecencyStore::with_path(data_path);

        let projects: Vec<Project> = vec![];
        let result = pick_project(&projects, &frecency, None);
        assert!(result.is_none());
    }

    // Integration test for the actual picker - requires terminal interaction
    #[test]
    #[ignore = "Interactive test: requires terminal for skim TUI"]
    fn test_pick_project_interactive() {
        use tempfile::TempDir;

        let temp = TempDir::new().unwrap();
        let data_path = temp.path().join("frecency.json");
        let frecency = FrecencyStore::with_path(data_path);

        let projects = vec![
            make_project("project-a"),
            make_project("project-b"),
            make_project("project-c"),
        ];

        // This will open the skim picker - user needs to select manually
        let result = pick_project(&projects, &frecency, None);
        println!("Selected: {:?}", result);
    }
}
