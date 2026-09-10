#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the GitCompletion directory junctions that make the module
    discoverable by PowerShell.

.DESCRIPTION
    Removes only the GitCompletion junctions from the two user module paths.
    The actual module at %LOCALAPPDATA%\vsDizzy\GitCompletion is left untouched,
    as are the parent Modules directories (requirement #6) — even if they
    become empty afterwards.

    A non-junction item at a link path is left alone with a warning so that
    user data is never destroyed.
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

    # Remove-Item on a junction removes ONLY the link, never the target directory's contents.
    # -Recurse is required because a junction has children (the target's entries); -Force
    # suppresses the confirmation prompt. Works in both Windows PowerShell 5.1 and PowerShell 7.
    Remove-Item -LiteralPath $LinkPath -Force -Recurse -ErrorAction Stop
    Write-Verbose "Removed junction: $LinkPath"
}