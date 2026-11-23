# GitCompletion

Native Git completion for **PowerShell 5.1** and **PowerShell 7**.

It uses the Git completion engine already shipped with **Git for Windows** instead of maintaining another implementation.

## How it works

```text
PowerShell → GitCompletion → Git for Windows → git-completion.bash
```

GitCompletion acts as a small bridge between PowerShell's native completion API and Git for Windows' Bash completion.

Git remains the source of truth.

## What it is

GitCompletion is intentionally small and focused.

It is **not a replacement for or competitor to** projects such as [posh-git](https://github.com/dahlbyk/posh-git), [PSGitCompletion](https://github.com/ModuleSigning/PSGitCompletion), or [git-completion](https://github.com/kazu-yamamoto/git-completion).

Those projects take different approaches and may provide much broader PowerShell integration.

GitCompletion simply lets PowerShell use **Git for Windows' own completion logic**.

## Installation

Download `GitCompletion.msi` from the [latest release](https://github.com/vsDizzy/git-completion/releases/latest) and run it.

The installation is **per-user**.

**No administrator privileges or elevation are required.**

## Footprint

GitCompletion:

* installs only for the current user;
* does not modify the Git installation;
* adds its PowerShell module to the user's module paths;
* registers Git completion through PowerShell's native completion API.

Uninstalling GitCompletion removes the integration it installed.

## Requirements

* Windows
* Git for Windows
* PowerShell 5.1 or PowerShell 7+

No additional PowerShell modules are required.

## Releasing

Versions and the changelog are managed with [Changesets](https://github.com/changesets/changesets).

1. Add a changeset with every user-facing change: `npx changeset`.
2. Merge the "Version Packages" pull request that the `Version` workflow opens on `main`. It bumps the version in `package.json` and updates `CHANGELOG.md`.
3. Run the `Release to GitHub` workflow to build the MSI and publish the release.

## Limitations

GitCompletion relies on implementation details of Git for Windows, including its bundled `bash.exe` and `git-completion.bash`.

A Git for Windows update may change those internals and affect completion behavior.

**Use at your own risk.**
