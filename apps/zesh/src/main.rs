mod config;
mod discovery;
mod frecency;
mod picker;
mod zellij;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::process::Command;

#[derive(Parser)]
#[command(name = "zesh")]
#[command(about = "Fast terminal session manager for zellij")]
struct Cli {
    /// Fuzzy match query (optional)
    query: Option<String>,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// List active zellij sessions
    Ls,
    /// Kill a session
    Kill { name: String },
    /// Kill sessions for non-existent projects
    Clean,
    /// Open config in $EDITOR
    Config,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Ls) => cmd_ls()?,
        Some(Commands::Kill { name }) => cmd_kill(&name)?,
        Some(Commands::Clean) => cmd_clean()?,
        Some(Commands::Config) => cmd_config()?,
        None => {
            // Main flow: discover projects, pick, switch
            run_main_flow(cli.query.as_deref())?;
        }
    }

    Ok(())
}

/// Main flow: discover projects, pick one, switch to it
fn run_main_flow(query: Option<&str>) -> Result<()> {
    // Load configuration
    let cfg = config::Config::load()?;

    if cfg.roots.is_empty() {
        eprintln!("No roots configured. Run 'zesh config' to set up.");
        eprintln!("Config file: {}", config::Config::config_path()?.display());
        return Ok(());
    }

    // Discover projects
    let projects = discovery::discover_projects(&cfg);

    if projects.is_empty() {
        eprintln!("No projects found in configured roots.");
        return Ok(());
    }

    // Load frecency data
    let frecency = frecency::FrecencyStore::new()?;

    // If a query is provided, try direct match first
    if let Some(q) = query {
        // Try to find a single matching project
        if let Some(project) = picker::fuzzy_match_single(&projects, q) {
            return switch_to_project(&project);
        }
        // Multiple matches or no matches - show picker with query pre-filled
    }

    // Show interactive picker
    match picker::pick_project(&projects, &frecency, query) {
        Some(project) => switch_to_project(&project),
        None => {
            // User cancelled (Esc)
            Ok(())
        }
    }
}

/// Switch to a project's session, recording the access in frecency
fn switch_to_project(project: &discovery::Project) -> Result<()> {
    // Record access for frecency tracking
    let mut frecency = frecency::FrecencyStore::new()?;
    frecency.record_access(&project.path)?;

    // Switch to the project's session
    zellij::switch_to_project(project)?;
    Ok(())
}

/// List active zellij sessions
fn cmd_ls() -> Result<()> {
    let sessions = zellij::list_sessions()?;

    if sessions.is_empty() {
        println!("No active zellij sessions.");
    } else {
        for session in sessions {
            println!("{session}");
        }
    }

    Ok(())
}

/// Kill a zellij session by name
fn cmd_kill(name: &str) -> Result<()> {
    zellij::kill_session(name)?;
    println!("Killed session: {name}");
    Ok(())
}

/// Kill sessions that don't correspond to any known project
fn cmd_clean() -> Result<()> {
    // Load configuration and discover projects
    let cfg = config::Config::load()?;
    let projects = discovery::discover_projects(&cfg);

    // Get active sessions
    let sessions = zellij::list_sessions()?;

    // Find orphaned sessions
    let orphaned = zellij::find_orphaned_sessions(&sessions, &projects);

    if orphaned.is_empty() {
        println!("No orphaned sessions found.");
        return Ok(());
    }

    println!("Found {} orphaned session(s):", orphaned.len());
    for session in &orphaned {
        println!("  {session}");
    }

    // Kill each orphaned session
    for session in &orphaned {
        match zellij::kill_session(session) {
            Ok(()) => println!("Killed: {session}"),
            Err(e) => eprintln!("Failed to kill '{session}': {e}"),
        }
    }

    Ok(())
}

/// Open config file in $EDITOR
fn cmd_config() -> Result<()> {
    let config_path = config::Config::config_path()?;

    // Create parent directory if it doesn't exist
    if let Some(parent) = config_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Create default config if it doesn't exist
    if !config_path.exists() {
        let default_config = r#"# Zesh configuration
# Define roots to search for projects

# Example:
# [[roots]]
# path = "~/dev"
# depth = 2

# [[roots]]
# path = "~/src"
# depth = 3
# sparse_checkout = true
"#;
        std::fs::write(&config_path, default_config)?;
        println!("Created default config at: {}", config_path.display());
    }

    // Get editor from environment
    let editor = std::env::var("EDITOR").unwrap_or_else(|_| "vim".to_string());

    // Open in editor
    let status = Command::new(&editor)
        .arg(&config_path)
        .status()
        .map_err(|e| anyhow::anyhow!("Failed to open editor '{editor}': {e}"))?;

    if !status.success() {
        return Err(anyhow::anyhow!("Editor exited with non-zero status"));
    }

    Ok(())
}
