# Install WezTerm, JetBrains Mono Nerd Font and the Catppuccin Mocha OLED config on Windows.
# Runs standalone (no clone needed), from PowerShell:
#   irm https://raw.githubusercontent.com/okdunn/.dotfiles/main/install/wezterm-windows.ps1 | iex
# Rerun to update the config. A different existing config is backed up first.
# Run as a script block: under `irm | iex` this runs in your session, where `exit` would
# close the window and settings would leak into it
& {
    $ErrorActionPreference = 'Stop'

    $url = if ($env:WEZTERM_LUA_URL) { $env:WEZTERM_LUA_URL } else {
        'https://raw.githubusercontent.com/okdunn/.dotfiles/main/wezterm/.config/wezterm/wezterm.lua'
    }
    # WezTerm's documented Windows location; it is read when no XDG config exists
    $config = Join-Path $HOME '.wezterm.lua'

    function Log($msg) { Write-Host "==> $msg" -ForegroundColor Green }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host '==> ERROR: winget not found. Install "App Installer" from the Microsoft Store, then rerun this script.' -ForegroundColor Red
        return
    }

    function Test-WingetInstalled($id) {
        winget list -e --id $id --accept-source-agreements *> $null
        return $LASTEXITCODE -eq 0
    }

    function Install-IfMissing($id, $name, [bool]$present) {
        if ($present) { Log "$name already installed"; return }
        Log "Installing $name..."
        winget install -e --id $id --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "winget could not install $name ($id)" }
    }

    # A WezTerm installed without winget (zip, installer from the website) is still on PATH
    $hasWezterm = (Test-WingetInstalled 'wez.wezterm') -or [bool](Get-Command wezterm -ErrorAction SilentlyContinue)
    Install-IfMissing 'wez.wezterm' 'WezTerm' $hasWezterm
    Install-IfMissing 'DEVCOM.JetBrainsMonoNerdFont' 'JetBrains Mono Nerd Font' (Test-WingetInstalled 'DEVCOM.JetBrainsMonoNerdFont')

    # Download first, so a failed fetch never touches the existing config
    $tmp = [IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp
    } catch {
        Remove-Item $tmp -ErrorAction SilentlyContinue
        Write-Host "==> ERROR: Could not download $url" -ForegroundColor Red
        return
    }

    if ((Test-Path $config) -and ((Get-FileHash $tmp).Hash -eq (Get-FileHash $config).Hash)) {
        Remove-Item $tmp
        Log 'WezTerm config already up to date'
        return
    }
    if (Test-Path $config) {
        $backup = "$config.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item $config $backup
        Log "Backed up your existing config to $backup"
    }
    Move-Item $tmp $config
    Log "WezTerm config installed at $config. Restart WezTerm to apply it."
}
