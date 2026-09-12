# Specification: Multi-Channel Release Promotion

## 1. Architecture & Core Concepts

This specification defines the process of building a product version once and independently promoting it to multiple distribution channels (e.g., WinGet, Chocolatey, Scoop). The architecture relies on a **"Floating Release / Fixed Publication Record"** pattern.

The workflow utilizes a two-tier Git tag structure:

| Tag Format              | Role                                                                    | Scope & Mutability                                                 |
| ----------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `v<version>/release`    | Identifies the current preparation state of the release.                | **Mutable** (Floating branch pointer)                              |
| `v<version>/<provider>` | Locks the execution context, scripts, manifests, and publication state. | **Immutable** (Temporary during execution, Permanent upon success) |

**Tag Tree Example:**

```text
v0.1.1/release (Preparation state - shifts on hotfixes)
 │
 ├── v0.1.1/winget (State lock & manifest record)
 ├── v0.1.1/choco  (State lock & manifest record)
 └── v0.1.1/scoop  (State lock & manifest record)

```

## 2. Storage & Immutability Boundaries

To prevent false assumptions regarding binary storage, the release environment explicitly separates source assets from distributed binaries:

```text
┌───────────────────────────────────────────┐      ┌──────────────────────────────────────────┐
│              Git Repository               │      │              GitHub Release              │
├───────────────────────────────────────────┤      ├──────────────────────────────────────────┤
│ • Pipeline workflows & scripts            │      │ • Distributable binaries (.msi, .zip)    │
│ • Package manifests (.yaml, .json)        │ ---> │ • Cryptographic link: Manifest stores    │
│ • State lock tags (v<version>/<provider>) │      │   SHA256 hash of the binary              │
└───────────────────────────────────────────┘      └──────────────────────────────────────────┘

```

- **What the Git Tag Freezes:** The pipeline scripts, package manifests, configuration files, SHA256 checksums, and the pipeline state lock.
- **What the Git Tag DOES NOT Freeze:** The heavy release binaries. Binaries reside in GitHub Releases external storage.
- **Integrity Guarantee:** Binary immutability is enforced via the SHA256 checksum embedded in the Git-frozen manifest. If a binary in GitHub Releases is modified or replaced, client installations or package registry checks will immediately fail validation due to hash mismatch.

## 3. Workflows & Responsibilities

Responsibilities are strictly separated across dedicated GitHub Actions workflows.

**A. Release Workflow (`release.yml`)**
Owns the release preparation state.

- **Responsibilities:** Resolves the product version, compiles binaries, creates/updates the GitHub Release, uploads binary assets, computes SHA256 hashes, and sets/moves the `v<version>/release` tag.
- **Exclusions:** Does not evaluate channel publication status and never triggers provider publication workflows.

**B. Provider Publish Workflows (`winget-publish.yml`, etc.)**
Owns the publication state for a specific distribution channel.

- **Responsibilities:** Scans for candidate versions, creates the `v<version>/<provider>` tag, checks out repository context at that tag, downloads the target binary, verifies its integrity, and submits the package to the provider registry.
- **Exclusions:** Never compiles binaries, never alters the `v<version>/release` tag, and operates independently of other channels.

**Candidate Discovery:**
Provider workflows process candidate versions in strictly ascending order. A version is eligible for Provider X only when:

1. The `v<version>/release` tag exists.
2. The GitHub Release exists with required binary assets uploaded.
3. The `v<version>/X` tag **does not exist**.

## 4. Publication State Machine

Each provider workflow follows this strict sequence to ensure idempotency and execution consistency:

1. **Validation:** Verify whether `v<version>/<provider>` exists.

- _Exists:_ Abort execution (ERROR). Duplicate publication attempt.
- _Absent:_ Proceed to Step 2.

2. **State Lock Creation:** Create the temporary `v<version>/<provider>` tag at the current `v<version>/release` commit. This acts as a concurrency lock and freezes the manifest context.
3. **Execution & Submission:**

- **Checkout:** Clone the repository strictly at `v<version>/<provider>`.
- **Fetch Asset:** Download the binary from the GitHub Release.
- **Publish:** Submit the package using the checked-out manifests and downloaded binary.

4. **State Resolution:**

- _Success:_ The tag is retained permanently as an immutable publication record.
- _Failure:_ The temporary tag is **deleted**, unlocking the version for future retry attempts.

```text
v<version>/release
        │
        ▼
check v<version>/<provider>
        │
   ┌────┴────┐
   │         │
 exists    absent
   │         │
   ▼         ▼
 ERROR   create temp tag (state lock)
             │
             ▼
      checkout repo at tag
             │
             ▼
    download binary from GH
             │
             ▼
      submit to registry
             │
        ┌────┴────┐
        │         │
     success   failure
        │         │
        ▼         ▼
   KEEP (Lock)  DELETE (Unlock)

```

**Hotfix Behaviour:**
If a release requires modification before all providers are published, `v<version>/release` is shifted to a new commit and the binary assets in GitHub Releases are updated. Previously published channels remain anchored to their permanent publication records (`v<version>/<provider>`). Pending channels automatically pick up the updated commit and binaries on their next run.

## 5. System Invariants

1. **Single Release Pointer:** One product version corresponds to exactly one floating `v<version>/release` tag.
2. **Context Isolation:** All publication tasks must execute strictly from the checked-out `v<version>/<provider>` tag context, never from floating branches.
3. **No Local Compilation:** Provider workflows must never compile binaries. They consume pre-built assets from GitHub Releases verified against manifest checksums.
4. **Permanent Publication Record:** Once publication succeeds, `v<version>/<provider>` becomes a permanent record and must never be force-moved, overwritten, or deleted.
5. **Mandatory Pre-Execution Tagging:** Registry submission must not begin before the local `v<version>/<provider>` tag is successfully created.
6. **Failure Cleanup:** Any failure during checkout, asset download, or registry submission must trigger immediate deletion of the temporary `v<version>/<provider>` tag.
