# Enhanced Disk Export for Lightroom

**Enhanced Disk Export** is a Lightroom Classic export plug-in that significantly expands standard saving capabilities. The core idea is to provide users with flexible export path configuration using templates (tokens), similar to the export logic in **Capture One**.

The plug-in replaces the standard "Export To: Hard Drive" panel with a more powerful version, allowing you to automatically create subfolder structures based on photo metadata. This makes the export process more organized and automated.

## Key Features

- **Token-based Export** — compose export paths using metadata variables like `{{catalog}}/{{image yyyy}}/{{rating}}`.
- **Capture One Principle** — dynamic on-the-fly subdirectory creation based on the properties of each individual photo.
- **Flexible Conflict Handling** — choose what happens when a file with the same name exists: prompt the user, auto-rename, overwrite, or skip.
- **Advanced Post-Processing** — automatically open the folder in Finder/Explorer, pass the file to a third-party application (e.g., Photoshop or retouching software), or run a custom script immediately after export.
- **Lightroom UI Integration** — uses the standard progress bar and supports operation cancellation.

## Installation

1. Copy the `EnhancedDiskExport.lrdevplugin` folder (or the compiled `EnhancedDiskExport.lrplugin`) to a safe location on your computer.
2. In Lightroom Classic, go to `File` → `Plug-in Manager…`.
3. Click `Add` and select the plug-in folder.
4. In the Export window (`File` → `Export…`), select **Enhanced Disk Export** from the service list (Export To) in the top-left corner.

## Usage and Tokens

Path management is built on "tokens" — special placeholders in double curly braces. During export, the plug-in replaces them with real metadata values from each photo.

### Available Tokens

| Token | Description |
| ----- | ----------- |
| `{{catalog}}`, `{{catalog name}}` | Active catalog name. |
| `{{date}}`, `{{yyyy}}`, `{{mm}}`, `{{dd}}` | Current date (export time). |
| `{{image date}}`, `{{image yyyy}}`, `{{image mm}}`, `{{image dd}}` | Capture date from photo metadata. |
| `{{orientation}}` | Orientation: "Portrait", "Landscape", or "Square" (respecting crop). |
| `{{folder}}` | Name of the source folder containing the photo. |
| `{{rating}}` | Star rating (0–5). |
| `{{color}}` | Color label (or `nocolor`). |

## Existing File Actions

You can choose how the plug-in handles collisions if a file already exists in the destination:
- **Ask what to do** — prompt for action for each case (rename, overwrite, or skip).
- **Choose a new name** — automatically append a sequence number (`_2`, `_3`, ...) until the name is unique.
- **Overwrite WITHOUT WARNING** — immediately overwrite files (caution!).
- **Skip** — skip export if the file already exists.

## License

This project is distributed under the **GPLv3** license. See the [LICENSE](./LICENSE) file for details.
