# Screenshot Tool

A robust cross-platform screenshot management utility with flexible capture modes and output options, designed for easy keyboard binding integration.

## Features

### Capture Modes
- **Interactive** (Default): User-selectable area or window capture - the most flexible option
- **Main Monitor**: Capture only the main/primary monitor
- **All Screens**: Capture all connected displays as a single image

### Output Behaviors
- **Clipboard** (Default): Copy image directly to clipboard without saving to file
- **Save to File**: Store screenshot in configured directory with timestamp
- **Save & Copy Path**: Save file and copy its full path to clipboard

## Usage

```bash
screenshot [capture_mode] [output_behavior] [options]
```

### Capture Mode Flags (mutually exclusive)
- `-i`, `--interactive` - Interactive selection mode (default)
- `-m`, `--monitor` - Capture main monitor only
- `-a`, `--all` - Capture all screens

### Output Behavior Flags (mutually exclusive)
- `-c`, `--clipboard` - Copy image to clipboard only (default, no file saved)
- `-s`, `--save` - Save to file only
- `-p`, `--path` - Save file and copy path to clipboard

### Additional Options
- `-d`, `--dir <path>` - Override default save directory
- `-f`, `--format <type>` - Image format: png (default), jpg, pdf, tiff
- `-n`, `--name <prefix>` - Custom filename prefix
- `-x`, `--silent` - Disable sound effects
- `-h`, `--help` - Show usage information

## Examples

```bash
# Quick interactive capture to clipboard (default behavior)
screenshot

# Interactive selection saved to file
screenshot -s

# Capture main monitor to clipboard
screenshot -m

# Capture all screens, save and copy path
screenshot -a -p

# Interactive capture with custom name saved to file
screenshot -s -n "bugfix" 

# Silent capture of main monitor saved to file
screenshot -m -s -x

# Save to custom directory in PDF format
screenshot -s -d ~/Documents/captures -f pdf

# Interactive capture, save file and copy its path
screenshot -p
```

## Keyboard Binding Recommendations

Suggested keybindings for common workflows:

| Keybind | Command | Description |
|---------|---------|-------------|
| `Cmd+Shift+3` | `screenshot -a -s` | All screens capture to file |
| `Cmd+Shift+4` | `screenshot` | Interactive capture to clipboard (default) |
| `Cmd+Shift+5` | `screenshot -s` | Interactive capture to file |
| `Cmd+Ctrl+Shift+3` | `screenshot -m` | Main monitor to clipboard |
| `Cmd+Ctrl+Shift+4` | `screenshot -p` | Interactive capture, save & copy path |

## Configuration

### Default Settings
- **Capture Mode**: Interactive (region/window selection)
- **Output Mode**: Clipboard (no file saved)
- **Save Directory**: `~/Pictures/Screenshots/` (when saving files)
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