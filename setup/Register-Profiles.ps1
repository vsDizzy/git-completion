#Requires -Version 5.1
<#
.SYNOPSIS
    Registers or unregisters the GitCompletion profile block in the selected
    PowerShell 5.1 and/or PowerShell 7 user profiles.

.DESCRIPTION
    Adds or removes the following managed block from each selected user profile:

        # >>> GitCompletion BEGIN >>>
        Import-Module GitCompletion
        # <<< GitCompletion END <<<

    The following user profile paths are supported:

    Windows PowerShell 5.1:
        %USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1

    PowerShell 7:
        %USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1

    Registration is idempotent. Unregistration removes only the managed
    GitCompletion block and leaves all other profile content unchanged.

    Existing UTF-8 and UTF-16 encodings detected from their BOM are preserved.
    New or empty files are written as UTF-8 without BOM.

.PARAMETER Unregister
    Removes the GitCompletion block instead of adding it.

.PARAMETER PowerShell5
    Applies the operation to the Windows PowerShell 5.1 user profile.

.PARAMETER PowerShell7
    Applies the operation to the PowerShell 7 user profile.
#>

[CmdletBinding()]
param(
    [switch]$Unregister,
    [switch]$PowerShell5,
    [switch]$PowerShell7
)

$ErrorActionPreference = 'Stop'

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

$Profiles = @()

if ($PowerShell5) {
    $Profiles += Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
}

if ($PowerShell7) {
    $Profiles += Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
}

if ($Profiles.Count -eq 0) {
    throw 'At least one PowerShell version must be selected.'
}

function Get-ProfileEncoding {
    param(
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
    $Encoding = Get-ProfileEncoding -Bytes $Bytes
    $Text = [System.IO.File]::ReadAllText($Path, $Encoding)

    return [pscustomobject]@{
        Text     = $Text
        Encoding = $Encoding
    }
}

function Ensure-ProfileExists {
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

    Ensure-ProfileExists -Path $Path

    $Profile = Read-Profile -Path $Path
    $Text = $Profile.Text

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
        $Profile.Encoding
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

    $Profile = Read-Profile -Path $Path
    $Text = $Profile.Text
    $NewText = [regex]::Replace($Text, $RemovePattern, '')

    if ($NewText -eq $Text) {
        Write-Verbose "No GitCompletion block found in '$Path' -> nothing to remove."
        return
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $NewText,
        $Profile.Encoding
    )

    Write-Verbose "Removed GitCompletion block from: $Path"
}

foreach ($ProfilePath in $Profiles) {
    if ($Unregister) {
        Unregister-Profile -Path $ProfilePath
    }
    else {
        Register-Profile -Path $ProfilePath
    }
}
