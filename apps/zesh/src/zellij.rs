//! Zellij backend module for zesh
//!
//! Provides session management functionality for zellij:
//! - Listing active sessions
//! - Checking session existence
//! - Attaching to sessions
//! - Creating sessions with layout detection
//! - Switching to projects (attach or create)
//! - Killing sessions

use crate::discovery::Project;
use anyhow::{anyhow, Result};
use std::process::{Command, ExitStatus, Stdio};

/// Parse the output of `zellij list-sessions` into a list of session names
///
/// The output format from zellij list-sessions is one session per line,
/// potentially with additional metadata like "(current)" suffix.
pub fn parse_list_sessions_output(output: &str) -> Vec<String> {
    output
        .lines()
        .filter(|line| !line.trim().is_empty())
        .map(|line| {
            // Remove (current) suffix if present, and any other status suffixes
            let session_name = line.split_whitespace().next().unwrap_or(line);
            session_name.to_string()
        })
        .collect()
}

/// List all active zellij sessions
///
/// Runs `zellij list-sessions` and parses the output.
pub fn list_sessions() -> Result<Vec<String>> {
    let output = Command::new("zellij")
        .arg("list-sessions")
        .output()
        .map_err(|e| anyhow!("Failed to run zellij list-sessions: {e}"))?;

    if !output.status.success() {
        // zellij returns non-zero if no sessions exist
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.contains("No active zellij sessions found") || output.stdout.is_empty() {
            return Ok(Vec::new());
        }
        return Err(anyhow!(
            "zellij list-sessions failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(parse_list_sessions_output(&stdout))
}

/// Check if a session with the given name exists
pub fn session_exists(name: &str) -> Result<bool> {
    let sessions = list_sessions()?;
    Ok(sessions.iter().any(|s| s == name))
}

/// Build the command to attach to an existing session
///
/// Returns the Command configured for attaching. The caller is responsible
/// for executing it (typically via `exec` or `spawn`).
pub fn build_attach_command(name: &str) -> Command {
    let mut cmd = Command::new("zellij");
    cmd.arg("attach").arg(name);
    cmd
}

/// Attach to an existing zellij session
///
/// Spawns zellij attached to the session and waits for it to exit.
/// Returns an error if attachment fails.
pub fn attach_session(name: &str) -> Result<ExitStatus> {
    let mut cmd = build_attach_command(name);

    // Inherit stdio so the user can interact with zellij
    cmd.stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());

    let status = cmd
        .status()
        .map_err(|e| anyhow!("Failed to attach to session '{name}': {e}"))?;

    Ok(status)
}

/// Build the command to create a new session for a project
///
/// The session will:
/// - Use the project.name as the session name
/// - Start in the project.path directory
/// - Use .zellij.kdl layout if present, otherwise user's default layout
///
/// Note: We always use --new-session-with-layout because `zellij --session`
/// alone uses zellij's internal default, not ~/.config/zellij/layouts/default.kdl
pub fn build_create_command(project: &Project) -> Command {
    let mut cmd = Command::new("zellij");

    // Set session name
    cmd.arg("--session").arg(&project.name);

    // Always specify layout explicitly:
    // - Custom .zellij.kdl in project takes priority
    // - Otherwise use user's default layout at ~/.config/zellij/layouts/default.kdl
    //   (using full path to avoid layout name resolution issues)
    let layout_path = project.path.join(".zellij.kdl");
    if layout_path.exists() {
        cmd.arg("--new-session-with-layout")
            .arg(layout_path.to_string_lossy().as_ref());
    } else if let Some(home) = std::env::var_os("HOME") {
        let default_layout =
            std::path::PathBuf::from(home).join(".config/zellij/layouts/default.kdl");
        if default_layout.exists() {
            cmd.arg("--new-session-with-layout")
                .arg(default_layout.to_string_lossy().as_ref());
        }
        // If no layout exists, let zellij use its internal default
    }

    // Set the working directory for the session
    cmd.current_dir(&project.path);

    cmd
}

/// Create a new zellij session for a project
///
/// Uses the project's .zellij.kdl layout if present, otherwise default.
/// Starts in the project's directory.
pub fn create_session(project: &Project) -> Result<ExitStatus> {
    let mut cmd = build_create_command(project);

    // Inherit stdio so the user can interact with zellij
    cmd.stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());

    let status = cmd
        .status()
        .map_err(|e| anyhow!("Failed to create session '{}': {}", project.name, e))?;

    Ok(status)
}

/// Switch to a project's session
///
/// If a session with the project's name already exists, attach to it.
/// Otherwise, create a new session.
pub fn switch_to_project(project: &Project) -> Result<ExitStatus> {
    if session_exists(&project.name)? {
        attach_session(&project.name)
    } else {
        create_session(project)
    }
}

/// Build the command to kill a session
pub fn build_kill_command(name: &str) -> Command {
    let mut cmd = Command::new("zellij");
    cmd.arg("kill-session").arg(name);
    cmd
}

/// Kill a zellij session by name
pub fn kill_session(name: &str) -> Result<()> {
    let mut cmd = build_kill_command(name);

    let output = cmd
        .output()
        .map_err(|e| anyhow!("Failed to kill session '{name}': {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow!("Failed to kill session '{name}': {stderr}"));
    }

    Ok(())
}

/// Find sessions that don't correspond to any known project.
///
/// Compares session names against project names (which already handle collisions).
/// Used for the `clean` command to remove orphaned sessions.
pub fn find_orphaned_sessions(sessions: &[String], projects: &[Project]) -> Vec<String> {
    sessions
        .iter()
        .filter(|session| !projects.iter().any(|p| &p.name == *session))
        .cloned()
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use tempfile::TempDir;

    // =========================================================================
    // parse_list_sessions_output tests
    // =========================================================================

    #[test]
    fn test_parse_empty_output() {
        let output = "";
        let sessions = parse_list_sessions_output(output);
        assert!(sessions.is_empty());
    }

    #[test]
    fn test_parse_single_session() {
        let output = "my-session\n";
        let sessions = parse_list_sessions_output(output);
        assert_eq!(sessions, vec!["my-session"]);
    }

    #[test]
    fn test_parse_multiple_sessions() {
        let output = "session-a\nsession-b\nsession-c\n";
        let sessions = parse_list_sessions_output(output);
        assert_eq!(sessions, vec!["session-a", "session-b", "session-c"]);
    }

    #[test]
    fn test_parse_session_with_current_suffix() {
        // zellij marks the current session with (current)
        let output = "session-a\nmy-project (current)\nsession-b\n";
        let sessions = parse_list_sessions_output(output);
        assert_eq!(sessions, vec!["session-a", "my-project", "session-b"]);
    }

    #[test]
    fn test_parse_session_with_extra_whitespace() {
        let output = "  session-a  \n\n  session-b\n  \n";
        let sessions = parse_list_sessions_output(output);
        assert_eq!(sessions, vec!["session-a", "session-b"]);
    }

    #[test]
    fn test_parse_session_with_exited_suffix() {
        // zellij may show (EXITED) for dead sessions
        let output = "active-session\ndead-session (EXITED)\n";
        let sessions = parse_list_sessions_output(output);
        assert_eq!(sessions, vec!["active-session", "dead-session"]);
    }

    #[test]
    fn test_parse_no_trailing_newline() {
        let output = "session-a\nsession-b";
        let sessions = parse_list_sessions_output(output);
        assert_eq!(sessions, vec!["session-a", "session-b"]);
    }

    // =========================================================================
    // build_attach_command tests
    // =========================================================================

    #[test]
    fn test_build_attach_command_has_correct_args() {
        let cmd = build_attach_command("my-session");
        let args: Vec<_> = cmd.get_args().collect();

        assert_eq!(cmd.get_program(), "zellij");
        assert_eq!(args.len(), 2);
        assert_eq!(args[0], "attach");
        assert_eq!(args[1], "my-session");
    }

    #[test]
    fn test_build_attach_command_with_special_characters() {
        let cmd = build_attach_command("org/my-project");
        let args: Vec<_> = cmd.get_args().collect();

        assert_eq!(args[1], "org/my-project");
    }

    // =========================================================================
    // build_create_command tests
    // =========================================================================

    #[test]
    fn test_build_create_command_with_default_layout() {
        let temp = TempDir::new().unwrap();
        let project = Project {
            name: "my-project".to_string(),
            path: temp.path().to_path_buf(),
            repo_root: temp.path().to_path_buf(),
            worktree_branch: None,
            sparse_zone: None,
        };

        let cmd = build_create_command(&project);
        let args: Vec<_> = cmd.get_args().collect();

        assert_eq!(cmd.get_program(), "zellij");
        assert!(args.contains(&std::ffi::OsStr::new("--session")));
        assert!(args.contains(&std::ffi::OsStr::new("my-project")));
        // When user's default.kdl exists at ~/.config/zellij/layouts/default.kdl,
        // should use --new-session-with-layout with full path.
        // In test environment, HOME may not have this file, so behavior depends on system.
        // The important thing is we set --session and current_dir correctly.
    }

    #[test]
    fn test_build_create_command_uses_home_default_layout() {
        // Create a mock HOME with default.kdl
        let mock_home = TempDir::new().unwrap();
        let layout_dir = mock_home.path().join(".config/zellij/layouts");
        std::fs::create_dir_all(&layout_dir).unwrap();
        let default_layout = layout_dir.join("default.kdl");
        std::fs::write(&default_layout, "layout {}").unwrap();

        // Temporarily override HOME
        let original_home = std::env::var_os("HOME");
        std::env::set_var("HOME", mock_home.path());

        let project_dir = TempDir::new().unwrap();
        let project = Project {
            name: "my-project".to_string(),
            path: project_dir.path().to_path_buf(),
            repo_root: project_dir.path().to_path_buf(),
            worktree_branch: None,
            sparse_zone: None,
        };

        let cmd = build_create_command(&project);
        let args: Vec<_> = cmd.get_args().collect();

        // Restore HOME
        match original_home {
            Some(h) => std::env::set_var("HOME", h),
            None => std::env::remove_var("HOME"),
        }

        assert!(args.contains(&std::ffi::OsStr::new("--new-session-with-layout")));
        // Should contain the full path to default.kdl
        let layout_arg = args
            .iter()
            .find(|a| a.to_string_lossy().contains("default.kdl"));
        assert!(layout_arg.is_some(), "Should use full path to default.kdl");
    }

    #[test]
    fn test_build_create_command_with_custom_layout() {
        let temp = TempDir::new().unwrap();
        let layout_path = temp.path().join(".zellij.kdl");
        std::fs::write(&layout_path, "layout {}").unwrap();

        let project = Project {
            name: "my-project".to_string(),
            path: temp.path().to_path_buf(),
            repo_root: temp.path().to_path_buf(),
            worktree_branch: None,
            sparse_zone: None,
        };

        let cmd = build_create_command(&project);
        let args: Vec<_> = cmd.get_args().collect();

        assert_eq!(cmd.get_program(), "zellij");
        assert!(args.contains(&std::ffi::OsStr::new("--session")));
        assert!(args.contains(&std::ffi::OsStr::new("--new-session-with-layout")));
        // Should contain the actual layout path
        let layout_arg = args
            .iter()
            .find(|a| a.to_string_lossy().contains(".zellij.kdl"));
        assert!(layout_arg.is_some(), "Layout path should be in args");
    }

    #[test]
    fn test_build_create_command_sets_working_directory() {
        let temp = TempDir::new().unwrap();
        let project = Project {
            name: "my-project".to_string(),
            path: temp.path().to_path_buf(),
            repo_root: temp.path().to_path_buf(),
            worktree_branch: None,
            sparse_zone: None,
        };

        let cmd = build_create_command(&project);
        assert_eq!(cmd.get_current_dir(), Some(temp.path()));
    }

    // =========================================================================
    // build_kill_command tests
    // =========================================================================

    #[test]
    fn test_build_kill_command_has_correct_args() {
        let cmd = build_kill_command("my-session");
        let args: Vec<_> = cmd.get_args().collect();

        assert_eq!(cmd.get_program(), "zellij");
        assert_eq!(args.len(), 2);
        assert_eq!(args[0], "kill-session");
        assert_eq!(args[1], "my-session");
    }

    // =========================================================================
    // find_orphaned_sessions tests
    // =========================================================================

    /// Helper to create a Project with just a name (for orphan detection tests)
    fn project_with_name(name: &str) -> Project {
        Project {
            name: name.to_string(),
            path: PathBuf::from("/dummy"),
            repo_root: PathBuf::from("/dummy"),
            worktree_branch: None,
            sparse_zone: None,
        }
    }

    #[test]
    fn test_find_orphaned_sessions_empty_lists() {
        let sessions: Vec<String> = vec![];
        let projects: Vec<Project> = vec![];

        let orphaned = find_orphaned_sessions(&sessions, &projects);
        assert!(orphaned.is_empty());
    }

    #[test]
    fn test_find_orphaned_sessions_no_orphans() {
        let sessions = vec!["project-a".to_string(), "project-b".to_string()];
        let projects = vec![
            project_with_name("project-a"),
            project_with_name("project-b"),
        ];

        let orphaned = find_orphaned_sessions(&sessions, &projects);
        assert!(orphaned.is_empty());
    }

    #[test]
    fn test_find_orphaned_sessions_all_orphaned() {
        let sessions = vec!["old-project".to_string(), "deleted-project".to_string()];
        let projects = vec![project_with_name("current-project")];

        let orphaned = find_orphaned_sessions(&sessions, &projects);
        assert_eq!(
            orphaned,
            vec!["old-project".to_string(), "deleted-project".to_string()]
        );
    }

    #[test]
    fn test_find_orphaned_sessions_mixed() {
        let sessions = vec![
            "still-exists".to_string(),
            "orphaned".to_string(),
            "also-exists".to_string(),
        ];
        let projects = vec![
            project_with_name("still-exists"),
            project_with_name("also-exists"),
        ];

        let orphaned = find_orphaned_sessions(&sessions, &projects);
        assert_eq!(orphaned, vec!["orphaned".to_string()]);
    }

    #[test]
    fn test_find_orphaned_sessions_with_collision_resolved_names() {
        // Session names can include parent directory for collision resolution
        let sessions = vec![
            "org-a/api".to_string(),
            "org-b/api".to_string(),
            "orphaned/api".to_string(),
        ];
        let projects = vec![
            project_with_name("org-a/api"),
            project_with_name("org-b/api"),
        ];

        let orphaned = find_orphaned_sessions(&sessions, &projects);
        assert_eq!(orphaned, vec!["orphaned/api".to_string()]);
    }

    // =========================================================================
    // Integration tests (require zellij to be installed)
    // These are marked #[ignore] for CI/automated testing
    // =========================================================================

    #[test]
    #[ignore = "Integration test: requires zellij installed"]
    fn test_list_sessions_integration() {
        // This will actually call zellij
        let result = list_sessions();
        // Should at least not panic - empty list is fine if no sessions
        assert!(result.is_ok());
    }

    #[test]
    #[ignore = "Integration test: requires zellij installed"]
    fn test_session_exists_integration() {
        // Check for a session that definitely doesn't exist
        let result = session_exists("nonexistent-test-session-12345");
        assert!(result.is_ok());
        assert!(!result.unwrap());
    }
}
