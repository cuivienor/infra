# Tmux Sessionizer Specification

## Purpose
A command-line tool to quickly find, create, and switch between tmux sessions for project directories. Inspired by ThePrimeagen's workflow for rapid project navigation.

## Current Behavior

### Core Functionality
The script (`t`) provides fast project switching with tmux session management:

1. **Project Discovery**: Finds git repositories in predefined locations
2. **Session Management**: Creates/attaches tmux sessions named after projects
3. **Project Initialization**: Sources `.t` files for custom project setup

### Usage Patterns

#### No Arguments
```bash
t
```
- Searches for all git projects in configured directories
- Shows interactive fzf picker
- Creates/switches to tmux session for selected project

#### With Directory Argument
```bash
t /path/to/project
```
- If path exists: uses that directory
- If path doesn't exist: uses zoxide for fuzzy search
- Creates/switches to tmux session

#### With Search Term
```bash
t project-name
```
- Uses zoxide interactive search to find matching directories
- Creates/switches to tmux session

### Project Discovery Logic

Searches for git repositories (`.git` directories) in:
- `$HOME` (depth: 2)
- `$HOME/dev` (depth: 2)  
- `$HOME/src` (depth: 4)
- `$HOME/dev/src` (depth: 4)
- `$HOME/work/src` (depth: 4)

For `/src` directories, includes repositories up to 3 levels deep from the src root to support:
- Direct: `src/project`
- Organization: `src/org/project`
- Host-based: `src/github.com/org/project`

### Session Naming
- Takes basename of selected directory
- Replaces dots (`.`) with underscores (`_`)
- Example: `/home/user/dev/my.project` → session name: `my_project`

### Session Initialization
When creating a new session, checks for initialization scripts:
1. First looks for `$PROJECT_DIR/.t` (project-specific)
2. Falls back to `$HOME/.t` (global default)
3. Sources the file in the new session using `tmux send-keys`

### Tmux Behavior
- **Outside tmux**: Attaches to the session
- **Inside tmux**: Switches client to the session
- **No tmux running**: Starts tmux server and creates session
- **Session exists**: Switches to existing session
- **Session doesn't exist**: Creates new session

## Current Implementation Details

### Dependencies
- `tmux` - Terminal multiplexer
- `fd` - Fast file finder (for locating `.git` directories)
- `fzf` - Fuzzy finder (for interactive project selection)
- `zoxide` - Smart directory jumper (optional, for fuzzy search)
- `realpath` - Path canonicalization

### Key Functions
- `switch_to()` - Handles attaching/switching to sessions
- `has_session()` - Checks if tmux session exists
- `tmux_init()` - Sources initialization files
- `find_projects()` - Discovers git repositories

## Known Limitations

1. **Unquoted Variables**: Several variables aren't properly quoted, causing issues with spaces in paths
2. **No Error Handling**: Missing `set -e` and no validation of commands
3. **Performance**: Multiple `realpath` calls in loops, redundant sorting
4. **Complex Depth Logic**: The depth calculation for src directories is overly complex
5. **No Configuration**: Hardcoded search paths, no user customization
6. **Session Name Collisions**: Projects with same basename create conflicts
7. **Limited Initialization**: Only sources bash scripts, no other setup options

## Proposed Improvements

### Essential Fixes
- [ ] Add proper error handling (`set -euo pipefail`)
- [ ] Quote all variables correctly
- [ ] Validate dependencies on startup
- [ ] Improve session name uniqueness

### Enhancements
- [ ] Configuration file support (`.config/t/config.yaml`)
- [ ] Custom search paths
- [ ] Session templates beyond `.t` files
- [ ] Better project detection (not just git repos)
- [ ] Session persistence/restoration
- [ ] Multiple windows/panes setup
- [ ] Project-specific environment variables
- [ ] Recently used projects tracking
- [ ] Better zoxide integration

### Performance
- [ ] Cache project list
- [ ] Optimize directory traversal
- [ ] Reduce realpath calls

### User Experience
- [ ] Help/usage information
- [ ] Verbose/debug mode
- [ ] Preview in fzf (show project info)
- [ ] Colorized output
- [ ] Progress indicators for slow operations
