#Requires -Version 5.1
<#
.SYNOPSIS
    Makes the GitCompletion module discoverable by both Windows PowerShell 5.1
    and PowerShell 7 without copying the module files.

.DESCRIPTION
    The module is installed by the MSI to %LOCALAPPDATA%\vsDizzy\GitCompletion.
    This script creates a directory junction (mklink /J) named GitCompletion in
    each of the two user module paths so both PowerShell versions can find it
    via Get-Module -ListAvailable. Works without administrator privileges.

    Idempotent: a correct junction already in place is left untouched.
    A junction pointing at the wrong target is replaced. A non-junction item
    at the path is left alone with a warning.

.PARAMETER InstallDir
    The actual module directory. Defaults to %LOCALAPPDATA%\vsDizzy\GitCompletion.
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

            cmd /c rmdir "`"$LinkPath`"" 2>&1 | Out-Null
        }
        else {
            Write-Warning "'$LinkPath' exists but is not a junction. Leaving it untouched."
            continue
        }
    }

    $Output = cmd /c mklink /J "`"$LinkPath`"" "`"$InstallDir`"" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create junction at '$LinkPath'. mklink output: $Output"
        exit 1
    }
}