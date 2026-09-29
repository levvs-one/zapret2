$ErrorActionPreference = 'SilentlyContinue'

$target = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'prosvet.exe'))

Get-CimInstance Win32_Process -Filter "Name='prosvet.exe'" |
    Where-Object {
        $_.ExecutablePath -and
        [string]::Equals(
            [IO.Path]::GetFullPath($_.ExecutablePath),
            $target,
            [StringComparison]::OrdinalIgnoreCase
        )
    } |
    ForEach-Object {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $_.ProcessId /T /F | Out-Null
    }
