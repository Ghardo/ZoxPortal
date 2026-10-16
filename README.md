# ZoxPortal

A global hotkey that opens a small Alacritty window with an **fzf picker over all zoxide directories**.

> **Windows only.** Most of the code here exists to work around Windows quirks (foreground lock, PowerToys starting windows in the background, positioning Explorer windows). On Linux the same idea is considerably simpler and doesn't need this project.

The idea is a **quick jump with automatic task execution**: instead of just opening a folder, ZoxPortal checks whether the project defines what "opening" it should mean. A Godot project, for example, is best opened directly in the Godot editor rather than in Explorer. A `runner` task in the project's mise config does exactly that.

After picking a directory, one of two things happens:

- **The folder has a mise task `runner`** (local `mise.toml` / `.mise.toml`): an Alacritty window "Runner Terminal" opens in that folder and runs `mise r runner`.
- **Otherwise:** the folder opens in Windows Explorer, centered on the primary screen (1200×800).

## How it works

```
PowerToys shortcut
  └─ alacritty (alacritty-zoxide.toml) -e zoxide_launcher.cmd
       ├─ focus_window.ps1 -Ancestor     brings the fzf window to the foreground
       ├─ zoxide query -l | fzf          pick a directory
       └─ zoxide_backend.ps1 <path>      keeps running hidden, Alacritty closes
            ├─ mise task "runner" exists → new Alacritty running `mise r runner`
            │                              + focus_window.ps1 -ProcessId <pid>
            └─ otherwise                 → open Explorer and center it
```

| File | Purpose |
|---|---|
| `zoxide_launcher.cmd` | Entry point, runs inside the Alacritty window: fzf over `zoxide query -l`, passes the selection to the backend |
| `zoxide_backend.ps1` | Decides between mise runner and Explorer and opens the target |
| `focus_window.ps1` | Brings an Alacritty window to the foreground (works around the Windows foreground lock with an Alt key trick) |
| `alacritty-zoxide.toml` | Dedicated Alacritty config: imports the regular config, only sets font size and start position |

### Design notes

- **The launcher is a cmd script on purpose.** It used to be a PowerShell script, but `pwsh` startup added noticeable delay before the picker appeared. `pwsh` now only runs where it doesn't block: the focus helper starts in parallel, and the backend starts hidden after the selection. Passing the selection through a temp file is the price for that.
- **Alacritty** starts fast, takes a dedicated config per call (`--config-file`) and runs every window as its own process, which `focus_window.ps1` relies on. Windows Terminal shares one process across all windows and starts slower.

## Requirements

- **Windows 10/11**
- [**Microsoft PowerToys**](https://learn.microsoft.com/windows/powertoys/) – *Keyboard Manager* module, provides the global shortcut
- [**Alacritty**](https://alacritty.org/) – must be available as `alacritty` in `PATH`
- [**PowerShell 7**](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) – as `pwsh` in `PATH` (Windows PowerShell 5.1 is not enough, the scripts are started with `pwsh`)
- [**zoxide**](https://github.com/ajeetdsouza/zoxide) – with an already populated database (set up and used in your shell)
- [**fzf**](https://github.com/junegunn/fzf)
- [**mise**](https://mise.jdx.dev/) – optional, only needed for the runner feature

Install the tools e.g. via winget:

```powershell
winget install Microsoft.PowerToys Alacritty.Alacritty Microsoft.PowerShell ajeetdsouza.zoxide junegunn.fzf jdx.mise
```

## Installation

1. **Clone the repository anywhere**, e.g. `D:\ZoxPortal` (used in the examples below).
   The scripts find each other relative to their own location, so only the PowerToys shortcut (step 3) needs the actual path.

2. **Adjust `alacritty-zoxide.toml`.**
   - `import` points to the default location of the main Alacritty config (`~/AppData/Roaming/alacritty/alacritty.toml`). Adjust it only if yours lives elsewhere.
   - `window.position` is roughly centered for 2560×1440. Alacritty has no option to center a window, so adjust the values by hand for other resolutions.

3. **Create the shortcut in PowerToys.**
   PowerToys → *Keyboard Manager* → *Remap a shortcut* → add a new entry:

   | Field | Value |
   |---|---|
   | Shortcut | any, e.g. `Win + J` |
   | Action | `Run Program` |
   | App | `alacritty` (or the full path to `alacritty.exe`) |
   | Args | `--config-file "D:\ZoxPortal\alacritty-zoxide.toml" --title "ZoxPortal" -e "D:\ZoxPortal\zoxide_launcher.cmd"` |
   | Start in | `D:\ZoxPortal` |
   | Visibility | `Normal` |

   Replace `D:\ZoxPortal` with your clone location.

   PowerToys often starts the window in the background, which is why `zoxide_launcher.cmd` brings it to the front itself via `focus_window.ps1`.

4. **Runner task (optional).**
   In a project that should do something specific when jumped to, add a mise task `runner` to its `mise.toml`. Example for a Godot project, opening it directly in the editor:

   ```toml
   [tasks.runner]
   run = "godot --editor --path ."
   ```

   Any other command works the same way, e.g. `cargo run`, `npm run dev` or `code .`.

## Usage

Press the shortcut, search for a directory in fzf, open it with `Enter`. `Esc` cancels and closes the window.

## License

[MIT](LICENSE)
