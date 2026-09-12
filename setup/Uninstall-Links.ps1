#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the GitCompletion module junctions from the user PowerShell
    module paths.

.DESCRIPTION
    Removes only the GitCompletion directory junctions from the Windows
    PowerShell 5.1 and PowerShell 7 user module paths.

    The actual module at %LOCALAPPDATA%\vsDizzy\GitCompletion is left
    untouched, as are the parent Modules directories, even if they become
    empty afterwards.

    A non-junction item at a link path is left untouched with a warning to
    avoid deleting user data.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$LinkName = 'GitCompletion'

$ModulesDirs = @(
    (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules')
    (Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules')
)

foreach ($ModulesDir in $ModulesDirs) {
    $LinkPath = Join-Path $ModulesDir $LinkName

    $Existing = Get-Item -LiteralPath $LinkPath -ErrorAction SilentlyContinue

    if (-not $Existing) {
        Write-Verbose "No junction found at '$LinkPath' -> nothing to remove."
        continue
    }

    $IsJunction = ($Existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint

    if (-not $IsJunction) {
        Write-Warning "'$LinkPath' exists but is not a junction. Leaving it untouched."
        continue
    }

    Remove-Item -LiteralPath $LinkPath -Force -Recurse -ErrorAction Stop
    Write-Verbose "Removed junction: $LinkPath"
}
