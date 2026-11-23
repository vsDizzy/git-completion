# Changesets

Every user-facing change gets a changeset describing it:

```powershell
npx changeset
```

Commit the generated file together with the change. On `main`, the
`Version` workflow collects pending changesets into a "Version Packages"
pull request that bumps `package.json` and updates `CHANGELOG.md`.
