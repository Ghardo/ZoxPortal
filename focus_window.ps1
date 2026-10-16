# Brings an Alacritty window to the foreground.
#   -ProcessId <pid>  : focus the window of this process (Runner Terminal from the backend)
#   -Ancestor         : walk up the parent processes until alacritty.exe (fzf window from the launcher)
# Windows blocks SetForegroundWindow for background processes (foreground lock),
# hence the Alt key trick before the call.
param(
    [int]$ProcessId = 0,
    [switch]$Ancestor
)

$code = @'
using System;
using System.Runtime.InteropServices;
public class FocusWin32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
'@
Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue

if ($Ancestor) {
    $current = $PID
    for ($i = 0; $i -lt 10 -and $current; $i++) {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $current"
        if (-not $proc) { break }
        if ($proc.Name -eq "alacritty.exe") { $ProcessId = $current; break }
        $current = $proc.ParentProcessId
    }
}
if (-not $ProcessId) { exit }

# Wait until the window exists
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 50; $i++) {
    $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $p) { exit }
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { $hwnd = $p.MainWindowHandle; break }
    Start-Sleep -Milliseconds 50
}
if ($hwnd -eq [IntPtr]::Zero) { exit }

if ([FocusWin32]::IsIconic($hwnd)) { [FocusWin32]::ShowWindow($hwnd, 9) | Out-Null }

# Briefly press/release Alt so Windows allows the focus change
[FocusWin32]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
[FocusWin32]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)

[FocusWin32]::BringWindowToTop($hwnd) | Out-Null
[FocusWin32]::SetForegroundWindow($hwnd) | Out-Null
