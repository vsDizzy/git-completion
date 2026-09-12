<#
.SYNOPSIS
    Runs GitCompletion setup in all available PowerShell environments.

.DESCRIPTION
    Runs setup.ps1 using each available PowerShell executable:
    Windows PowerShell 5.1 and PowerShell 7.
#>

[CmdletBinding()]
param(
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$SetupScript = Join-Path $PSScriptRoot 'setup.ps1'

$PowerShellExecutables = @(
  'powershell.exe'
  'pwsh.exe'
)

$Arguments = @(
  '-NoProfile'
  '-ExecutionPolicy', 'Bypass'
  '-File', $SetupScript
)

if ($Uninstall) {
  $Arguments += '-Uninstall'
}

foreach ($Executable in $PowerShellExecutables) {
  $Command = Get-Command $Executable -CommandType Application -ErrorAction SilentlyContinue

  if (-not $Command) {
    Write-Verbose "$Executable not found in PATH."
    continue
  }

  Write-Verbose "Running setup with $($Command.Source)."

  & $Command.Source @Arguments

  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
