#Requires -Version 5.1
<#
.SYNOPSIS
    Registers the GitCompletion module in the user PowerShell module paths.

.DESCRIPTION
    The module is installed by the MSI to
    %LOCALAPPDATA%\vsDizzy\GitCompletion.

    This script creates directory junctions named GitCompletion in the
    Windows PowerShell 5.1 and PowerShell 7 user module paths, allowing
    both PowerShell versions to discover the installed module without
    copying its files.

    Works without administrator privileges.

    The script is idempotent:
    - An existing junction pointing to the correct module directory is left untouched.
    - A junction pointing to a different directory is replaced.
    - A non-junction item at the expected path is left untouched with a warning.

.PARAMETER InstallDir
    The directory containing the installed GitCompletion module.
    Defaults to %LOCALAPPDATA%\vsDizzy\GitCompletion.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'vsDizzy\GitCompletion')
)

$InstallDir = $InstallDir.TrimEnd('\', '"')

$ErrorActionPreference = 'Stop'
$LinkName = 'GitCompletion'

$ModulesDirs = @(
    (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules')
    (Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules')
)

if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
    Write-Error "GitCompletion is not installed at '$InstallDir'. Run the MSI installer first."
    exit 1
}

$ExpectedTarget = [System.IO.Path]::GetFullPath($InstallDir)

foreach ($ModulesDir in $ModulesDirs) {
    if (-not (Test-Path -LiteralPath $ModulesDir -PathType Container)) {
        New-Item -ItemType Directory -Path $ModulesDir -Force | Out-Null
    }

    $LinkPath = Join-Path $ModulesDir $LinkName
    $Existing = Get-Item -LiteralPath $LinkPath -ErrorAction SilentlyContinue

    if ($Existing) {
        $IsJunction = ($Existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint

        if ($IsJunction) {
            $ActualTarget = [System.IO.Path]::GetFullPath($Existing.Target)

            if ($ActualTarget -eq $ExpectedTarget) {
                continue
            }

            Remove-Item -LiteralPath $LinkPath -Force
        }
        else {
            Write-Warning "'$LinkPath' exists but is not a junction. Leaving it untouched."
            continue
        }
    }

    try {
        New-Item -ItemType Junction -Path $LinkPath -Target $InstallDir -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to create junction at '$LinkPath': $($_.Exception.Message)"
        exit 1
    }
}
