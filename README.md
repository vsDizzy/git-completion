# Git Completion for PowerShell

Git completion for PowerShell using Git for Windows' `git-completion.bash`.

## PowerShell 7

Place the module here:

```text
$HOME\Documents\PowerShell\Modules\GitCompletion\GitCompletion.psm1
```

Add to `$PROFILE`:

```powershell
Import-Module GitCompletion
```

Create the profile when needed:

```powershell
New-Item -ItemType File -Force $PROFILE
```

Then restart PowerShell.

## Windows PowerShell 5.1

Place the module here:

```text
$HOME\Documents\WindowsPowerShell\Modules\GitCompletion\GitCompletion.psm1
```

Add to `$PROFILE`:

```powershell
Import-Module GitCompletion
```

Create the profile when needed:

```powershell
New-Item -ItemType File -Force $PROFILE
```

Then restart PowerShell.
