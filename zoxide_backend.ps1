param([string]$TargetPath)

if (-not (Test-Path $TargetPath)) { exit }
Set-Location $TargetPath

$hasLocalMise = (Test-Path "mise.toml") -or (Test-Path ".mise.toml")
$hasRunner = $false

if ($hasLocalMise) {
    $tasks = mise tasks --no-header 2>$null
    if ($tasks -match '\brunner\b') {
        $hasRunner = $true
    }
}

if ($hasRunner) {
    $alacrittyToml = Join-Path $PSScriptRoot "alacritty-zoxide.toml"
    $alacrittyArgs = @(
        "--config-file", "`"$alacrittyToml`"",
        "--title", "`"Runner Terminal`"",
        "--working-directory", "`"$TargetPath`"",
        "-e", "pwsh", "-Command", "`"mise r runner`""
    )
    $runner = Start-Process alacritty -ArgumentList $alacrittyArgs -WindowStyle Normal -PassThru
    & (Join-Path $PSScriptRoot "focus_window.ps1") -ProcessId $runner.Id
} else {
    Invoke-Item $TargetPath

    $shellApp = New-Object -ComObject Shell.Application
    $explorerWin = $null

    for ($i = 0; $i -lt 30; $i++) {
        foreach ($win in $shellApp.Windows()) {
            if ($win.Document -and $win.Document.Folder.Self.Path -eq $TargetPath) {
                $explorerWin = $win
                break
            }
        }
        if ($explorerWin) { break }
        Start-Sleep -Milliseconds 100
    }

    if ($explorerWin) {
        $code = @'
        using System;
        using System.Runtime.InteropServices;
        public class Win32 {
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
            [DllImport("user32.dll")]
            public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        }
'@
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Windows.Forms

        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $width = 1200
        $height = 800
        $x = [math]::Floor(($screen.Width - $width) / 2)
        $y = [math]::Floor(($screen.Height - $height) / 2)

        [Win32]::ShowWindow([IntPtr]$explorerWin.HWND, 9) | Out-Null
        [Win32]::SetWindowPos([IntPtr]$explorerWin.HWND, [IntPtr]::Zero, $x, $y, $width, $height, 0x0004) | Out-Null
    }
}
