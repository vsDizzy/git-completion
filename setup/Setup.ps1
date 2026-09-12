#Requires -Version 5.1
<#
.SYNOPSIS
    Installs or uninstalls the GitCompletion module for the current PowerShell.

.DESCRIPTION
    Install:
      1. Resolves the GitCompletion module directory relative to this script.
      2. Creates or updates the GitCompletion module junction.
      3. Adds the GitCompletion marker block to the current PowerShell profile.

    Uninstall:
      1. Removes the GitCompletion junction if it exists.
      2. Removes the GitCompletion marker block from the current PowerShell profile.
      3. Missing junction/profile/block is not an error.
#>

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$LinkName = 'GitCompletion'

$ProfilePath = $PROFILE
$ModulesDir = Join-Path (Split-Path -Path $ProfilePath -Parent) 'Modules'

$InstallDir = Join-Path $PSScriptRoot '..\GitCompletion'
$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)

$BeginMarker = '# >>> GitCompletion BEGIN >>>'
$EndMarker = '# <<< GitCompletion END <<<'

$Block = $BeginMarker + "`r`n" +
'Import-Module GitCompletion' + "`r`n" +
$EndMarker + "`r`n"

$RemovePattern = '(?s)' +
[regex]::Escape($BeginMarker) +
'.*?' +
[regex]::Escape($EndMarker) +
'\r?\n?'

function Get-ProfileEncoding {
    param(
        [Parameter(Mandatory)]
        [byte[]]$Bytes
    )

    if ($Bytes.Length -ge 3 -and
        $Bytes[0] -eq 0xEF -and
        $Bytes[1] -eq 0xBB -and
        $Bytes[2] -eq 0xBF) {
        return [System.Text.UTF8Encoding]::new($true)
    }

    if ($Bytes.Length -ge 2 -and
        $Bytes[0] -eq 0xFF -and
        $Bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode
    }

    if ($Bytes.Length -ge 2 -and
        $Bytes[0] -eq 0xFE -and
        $Bytes[1] -eq 0xFF) {
        return [System.Text.Encoding]::BigEndianUnicode
    }

    return [System.Text.UTF8Encoding]::new($false)
}

function Read-Profile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $Bytes = [System.IO.File]::ReadAllBytes($Path)

    if ($Bytes.Length -eq 0) {
        return [pscustomobject]@{
            Text     = ''
            Encoding = [System.Text.UTF8Encoding]::new($false)
        }
    }

    $Encoding = Get-ProfileEncoding -Bytes $Bytes
    $Text = [System.IO.File]::ReadAllText($Path, $Encoding)

    [pscustomobject]@{
        Text     = $Text
        Encoding = $Encoding
    }
}

function Initialize-Profile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return
    }

    $ParentDir = Split-Path -Path $Path -Parent

    if (-not (Test-Path -LiteralPath $ParentDir -PathType Container)) {
        New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null
        Write-Verbose "Created directory: $ParentDir"
    }

    New-Item -ItemType File -Path $Path -Force | Out-Null
    Write-Verbose "Created profile: $Path"
}

function Register-Profile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Initialize-Profile -Path $Path

    $ProfileData = Read-Profile -Path $Path
    $Text = $ProfileData.Text

    if ($Text.Contains($Block)) {
        Write-Verbose "GitCompletion block already present in '$Path' -> skipping."
        return
    }

    if ($Text.Contains($BeginMarker) -or $Text.Contains($EndMarker)) {
        Write-Warning "'$Path' contains GitCompletion markers but not the expected block. Leaving it untouched."
        return
    }

    if ($Text.Length -gt 0 -and -not $Text.EndsWith("`n")) {
        $Text += "`r`n"
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Text + $Block,
        $ProfileData.Encoding
    )

    Write-Verbose "Added GitCompletion block to: $Path"
}

function Unregister-Profile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Verbose "Profile does not exist: $Path -> nothing to remove."
        return
    }

    $ProfileData = Read-Profile -Path $Path

    $NewText = [regex]::Replace(
        $ProfileData.Text,
        $RemovePattern,
        ''
    )

    if ($NewText -eq $ProfileData.Text) {
        Write-Verbose "No GitCompletion block found in '$Path' -> nothing to remove."
        return
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $NewText,
        $ProfileData.Encoding
    )

    Write-Verbose "Removed GitCompletion block from: $Path"
}

function Set-Junction {
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )

    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        Write-Error "GitCompletion is not installed at '$Target'. Run the MSI installer first."
        exit 1
    }

    $ExpectedTarget = [System.IO.Path]::GetFullPath($Target)

    if (-not (Test-Path -LiteralPath $ModulesDir -PathType Container)) {
        New-Item -ItemType Directory -Path $ModulesDir -Force | Out-Null
        Write-Verbose "Created modules directory: $ModulesDir"
    }

    $LinkPath = Join-Path $ModulesDir $LinkName
    $Existing = Get-Item -LiteralPath $LinkPath -ErrorAction SilentlyContinue

    if ($Existing) {
        $IsJunction = (
            $Existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint
        ) -eq [System.IO.FileAttributes]::ReparsePoint

        if ($IsJunction) {
            $ActualTarget = [System.IO.Path]::GetFullPath($Existing.Target)

            if ($ActualTarget -eq $ExpectedTarget) {
                Write-Verbose "Junction already correct at '$LinkPath' -> skipping."
                return
            }

            Remove-Item -LiteralPath $LinkPath -Force -Recurse -ErrorAction Stop
        }
        else {
            Write-Warning "'$LinkPath' exists but is not a junction. Leaving it untouched."
            return
        }
    }

    try {
        New-Item -ItemType Junction -Path $LinkPath -Target $Target -ErrorAction Stop | Out-Null
        Write-Verbose "Created junction at '$LinkPath' -> '$Target'."
    }
    catch {
        Write-Error "Failed to create junction at '$LinkPath': $($_.Exception.Message)"
        exit 1
    }
}

function Remove-Junction {
    $LinkPath = Join-Path $ModulesDir $LinkName
    $Existing = Get-Item -LiteralPath $LinkPath -ErrorAction SilentlyContinue

    if (-not $Existing) {
        Write-Verbose "No junction found at '$LinkPath' -> nothing to remove."
        return
    }

    $IsJunction = (
        $Existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint
    ) -eq [System.IO.FileAttributes]::ReparsePoint

    if (-not $IsJunction) {
        Write-Warning "'$LinkPath' exists but is not a junction. Leaving it untouched."
        return
    }

    Remove-Item -LiteralPath $LinkPath -Force -Recurse -ErrorAction Stop
    Write-Verbose "Removed junction: $LinkPath"
}

if ($Uninstall) {
    Remove-Junction
    Unregister-Profile -Path $ProfilePath
    exit 0
}

Set-Junction -Target $InstallDir
Register-Profile -Path $ProfilePath
