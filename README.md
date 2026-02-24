# Samsung OSS Drop History Builder

Reconstruct a clean, chronological Git history from Samsung Open Source kernel drops.

Samsung publishes kernel source as discrete release archives (e.g., `Kernel.tar.gz` inside a ZIP file) without public Git history.  
This tool converts multiple source drops into a synthetic Git repository with:

- One commit per release
- Commit dates matching publication date
- Annotated Git tags using the exact Samsung build ID (e.g., `A137FXXS9EYE2`)
- Clean diffs between drops
- Reproducible import process
- No system clock manipulation required

The resulting repository is fully buildable and suitable for:
- LineageOS bring-up
- Kernel patch tracking
- Defconfig evolution analysis
- Bisecting vendor changes across releases
- Public archival on GitHub

---

## Why This Exists

Samsung does not publish their kernel trees with version history on GitHub.  
Each release is a standalone archive.

This project reconstructs a logical Git history from those releases while preserving:

- Authentic release ordering
- Accurate tagging
- Vendor source integrity

---

## Requirements

- Bash
- git
- rsync
- tar

Linux or WSL recommended.

---

## Directory Layout

Place your Samsung kernel drops in the following structure:

```

drops/
  2023-05-10/
    A137FXXU2BWE6.Kernel.tar.gz
  2023-09-01/
    A137FXXS4CWI1.Kernel.tar.gz
  2024-05-20/
    A137FXXS9EYE2.Kernel.tar.gz

```

### Rules

1. Directory name must be the release date in `YYYY-MM-DD`
2. Each directory must contain exactly one file:
```

<SAMSUNG_BUILD_ID>.Kernel.tar.gz

```
3. The filename (before `.Kernel.tar.gz`) becomes the Git tag.

Example:
```

A137FXXS9EYE2.Kernel.tar.gz

```
Creates Git tag:
```

A137FXXS9EYE2

```

No prefixes are added.

---

## Usage

### 1. Create repository

```

mkdir kernel-history
cd kernel-history
git init

```

### 2. Place the script

Copy `import_samsung_drops.sh` into the repo root.

Make it executable:

```

chmod +x import_samsung_drops.sh

```

### 3. Run the importer

```

./import_samsung_drops.sh

```

---

## What the Script Does

For each drop:

- Cleans working tree
- Extracts kernel archive
- Detects kernel root (Makefile + Kconfig)
- Imports files
- Creates commit with:
  - Author: `oss.request@samsung.com`
  - Commit date = directory date
- Creates annotated tag equal to Samsung build ID

No global git config is modified.
No system clock changes are performed.

---

## Resulting History Example

```

* A137FXXS9EYE2
* A137FXXS4CWI1
* A137FXXU2BWE6

```

Each tag corresponds exactly to a Samsung release.

---

## Recommended Workflow

After import:

```

git checkout -b work/local-modifications

```

Keep vendor drop history separate from your patches.

---

## Notes

- This tool assumes each drop contains only kernel source.
- If Samsung packages multiple components in one archive, extract only the kernel tarball first.
- If two drops are identical, no commit is created.
- Tag collisions will abort execution.

---

## Use Cases

- LineageOS device bring-up
- Kernel diff analysis
- Tracking defconfig evolution
- Security review across releases
- Vendor patch auditing

---

## Disclaimer

This project does not redistribute Samsung source code.  
Users must obtain source archives directly from Samsung Open Source Release Center.
