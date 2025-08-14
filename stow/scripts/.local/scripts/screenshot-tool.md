# Screenshot Tool

A robust cross-platform screenshot management utility with flexible capture modes and output options, designed for easy keyboard binding integration.

## Features

### Capture Modes
- **Active Monitor**: Capture only the currently active monitor
- **All Screens**: Capture all connected displays
- **Interactive**: User-selectable area or window capture

### Output Behaviors
- **Save to File**: Store screenshot in configured directory with timestamp
- **Save & Copy Path**: Save file and copy its full path to clipboard
- **Clipboard Only**: Copy image directly to clipboard without saving

## Usage

```bash
screenshot [capture_mode] [output_behavior] [options]
```

### Capture Mode Flags (mutually exclusive)
- `-m`, `--monitor` - Capture active monitor only (default)
- `-a`, `--all` - Capture all screens
- `-i`, `--interactive` - Interactive selection mode

### Output Behavior Flags (mutually exclusive)
- `-s`, `--save` - Save to file only (default)
- `-p`, `--path` - Save file and copy path to clipboard
- `-c`, `--clipboard` - Copy image to clipboard only (no file saved)

### Additional Options
- `-d`, `--dir <path>` - Override default save directory
- `-f`, `--format <type>` - Image format: png (default), jpg, pdf, tiff
- `-n`, `--name <prefix>` - Custom filename prefix
- `-x`, `--silent` - Disable sound effects
- `-h`, `--help` - Show usage information

## Examples

```bash
# Quick fullscreen capture to file
screenshot

# Interactive selection to clipboard
screenshot -i -c

# Capture all screens, save and copy path
screenshot -a -p

# Interactive capture with custom name
screenshot -i -n "bugfix" 

# Silent capture of active monitor to clipboard
screenshot -m -c -x

# Save to custom directory in PDF format
screenshot -d ~/Documents/captures -f pdf
```

## Keyboard Binding Recommendations

Suggested keybindings for common workflows:

| Keybind | Command | Description |
|---------|---------|-------------|
| `Cmd+Shift+3` | `screenshot -a -s` | Full desktop capture to file |
| `Cmd+Shift+4` | `screenshot -i -s` | Interactive capture to file |
| `Cmd+Shift+5` | `screenshot -i -c` | Interactive capture to clipboard |
| `Cmd+Ctrl+Shift+3` | `screenshot -m -c` | Active monitor to clipboard |
| `Cmd+Ctrl+Shift+4` | `screenshot -i -p` | Interactive capture, copy path |

## Configuration

### Default Settings
- **Save Directory**: `~/Pictures/Screenshots/`
- **File Format**: PNG
- **Naming Convention**: `screenshot_YYYY-MM-DD_HH-MM-SS.[ext]`
- **With Prefix**: `[prefix]_YYYY-MM-DD_HH-MM-SS.[ext]`

### Environment Variables
- `SCREENSHOT_DIR` - Override default save directory
- `SCREENSHOT_FORMAT` - Override default image format
- `SCREENSHOT_SILENT` - Set to "1" to disable sounds by default

## Platform Support

### macOS (Current Implementation)
- Uses native `screencapture` utility
- Full support for all capture modes
- Native clipboard integration via `pbcopy`

### Linux (Planned)
- Will use `scrot` or `maim` for capture
- `xclip` for clipboard operations
- Wayland support via `grim`

### Windows (Future)
- PowerShell cmdlets or third-party tools
- Native clipboard support

## Installation

1. Place script in your PATH (e.g., `~/.local/scripts/screenshot`)
2. Make executable: `chmod +x screenshot`
3. Configure keyboard shortcuts in your OS/WM settings

## Dependencies

### macOS
- `screencapture` (built-in)
- `pbcopy` (built-in)

### Linux (when implemented)
- `scrot` or `maim`
- `xclip` or `xsel`
- `grim` (for Wayland)

## Error Handling

The script includes robust error handling for:
- Invalid flag combinations
- Missing directories (auto-creates if needed)
- Permission issues
- Clipboard failures (falls back to file save)

## Exit Codes

- `0` - Success
- `1` - Invalid arguments
- `2` - Capture failed
- `3` - Clipboard operation failed
- `4` - File system error

## Future Enhancements

- [ ] Multi-platform support (Linux, Windows)
- [ ] OCR text extraction option
- [ ] Automatic upload to image hosting
- [ ] Screenshot annotation mode
- [ ] Video recording mode
- [ ] Custom file naming templates
- [ ] Integration with notification system
- [ ] Screenshot history/gallery viewer