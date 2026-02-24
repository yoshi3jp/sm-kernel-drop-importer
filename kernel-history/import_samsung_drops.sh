#!/usr/bin/env bash
set -euo pipefail

# Run this script from inside your git repo (kernel-history/)
REPO_DIR="$(pwd)"
DROPS_DIR="../drops"   # adjust if needed

# Minimal excludes: keep conservative to preserve vendor drops "as shipped".
# Add only if Samsung drops include obvious build outputs (often they don't).
EXCLUDES=(
  "--exclude=.git"
)

# Local, repo-only identity (also reinforced by per-commit env below)
git config --local user.name  "Samsung OSS Import" >/dev/null
git config --local user.email "oss.request@samsung.com" >/dev/null

# Safety: refuse to run if repo has uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: Repo has uncommitted changes. Commit/stash first."
  exit 1
fi

# Iterate drops by date directory name
for drop_date in $(ls -1 "${DROPS_DIR}" | sort); do
  drop_path="${DROPS_DIR}/${drop_date}"
  [[ -d "${drop_path}" ]] || continue

  # Find exactly one *.Kernel.tar.gz in the directory
  shopt -s nullglob
  archives=("${drop_path}"/*.Kernel.tar.gz)
  shopt -u nullglob

  if [[ ${#archives[@]} -ne 1 ]]; then
    echo "ERROR: ${drop_path} must contain exactly one '*.Kernel.tar.gz' (found ${#archives[@]})."
    exit 1
  fi

  archive="${archives[0]}"
  base="$(basename "${archive}")"

  # Tag name is everything before ".Kernel.tar.gz"
  tag="${base%.Kernel.tar.gz}"

  # Basic sanity check (optional): ensure tag looks like Samsung build id
  # Example: A137FXXS9EYE2 (but don't over-restrict; Samsung varies)
  if [[ ! "${tag}" =~ ^[A-Z0-9]+$ ]]; then
    echo "ERROR: Derived tag '${tag}' contains non [A-Z0-9] characters."
    echo "Rename archive to: <SAMSUNG_BUILD_ID>.Kernel.tar.gz"
    exit 1
  fi

  echo "=== Importing ${drop_date}  tag=${tag}  archive=$(basename "${archive}") ==="

  # Clean working tree to avoid carry-over
  git reset --hard
  git clean -fdx

  # Extract into a temporary directory
  tmpdir="$(mktemp -d)"
  tar -xzf "${archive}" -C "${tmpdir}"

  # Heuristic: find kernel root inside extracted content.
  # Many drops contain a top folder; we locate by presence of Makefile + Kconfig.
  kernel_root=""
  while IFS= read -r -d '' d; do
    if [[ -f "${d}/Makefile" && -f "${d}/Kconfig" ]]; then
      kernel_root="${d}"
      break
    fi
  done < <(find "${tmpdir}" -maxdepth 4 -type d -print0)

  if [[ -z "${kernel_root}" ]]; then
    echo "ERROR: Could not locate kernel root (Makefile+Kconfig) inside ${base}"
    rm -rf "${tmpdir}"
    exit 1
  fi

  # Sync extracted kernel into repo
  rsync -a --delete "${EXCLUDES[@]}" "${kernel_root}/" "${REPO_DIR}/"

  rm -rf "${tmpdir}"

  # Stage and commit
  git add -A

  if git diff --cached --quiet; then
    echo "No changes vs previous import; skipping commit/tag for ${tag}"
    continue
  fi

  # Set commit identity + timestamps WITHOUT touching system clock
  export GIT_AUTHOR_NAME="Samsung OSS Import"
  export GIT_AUTHOR_EMAIL="oss.request@samsung.com"
  export GIT_COMMITTER_NAME="Samsung OSS Import"
  export GIT_COMMITTER_EMAIL="oss.request@samsung.com"

  export GIT_AUTHOR_DATE="${drop_date}T00:00:00Z"
  export GIT_COMMITTER_DATE="${drop_date}T00:00:00Z"

  git commit -m "Samsung kernel source drop ${tag}"

  # Create annotated tag EXACTLY as Samsung version string (no prefix)
  if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
    echo "ERROR: Tag ${tag} already exists. Resolve collision manually."
    exit 1
  fi
  git tag -a "${tag}" -m "Samsung kernel drop ${tag} (${drop_date})"

done

echo "Done."
