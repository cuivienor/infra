mod config;

use anyhow::Result;
use clap::{Parser, Subcommand};

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
        Some(Commands::Ls) => {
            println!("TODO: List sessions");
        }
        Some(Commands::Kill { name }) => {
            println!("TODO: Kill session: {}", name);
        }
        Some(Commands::Clean) => {
            println!("TODO: Clean orphaned sessions");
        }
        Some(Commands::Config) => {
            println!("TODO: Open config");
        }
        None => {
            // Main flow: discover projects, pick, switch
            if let Some(query) = cli.query {
                println!("TODO: Fuzzy match for: {}", query);
            } else {
                println!("TODO: Interactive picker");
            }
        }
    }

    Ok(())
}
