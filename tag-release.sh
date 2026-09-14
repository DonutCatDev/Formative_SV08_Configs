#!/usr/bin/env bash

set -Eeuo pipefail

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

command -v git >/dev/null 2>&1 || die 'git is required'
command -v date >/dev/null 2>&1 || die 'date is required'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'tag-release.sh must be stored inside the Formative_SV08_Configs repository'
cd "$REPO_ROOT"

[[ -z "$(git status --porcelain=v1)" ]] ||
    die 'the working tree is not clean; commit or stash changes before tagging'

git remote get-url origin >/dev/null 2>&1 || die 'the repository has no origin remote'

UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" ||
    die 'the current branch has no upstream; push the branch before tagging'

AHEAD_COUNT="$(git rev-list --count "$UPSTREAM"..HEAD)"
[[ "$AHEAD_COUNT" == 0 ]] ||
    die "HEAD is $AHEAD_COUNT commit(s) ahead of $UPSTREAM; push the branch before tagging"

read -r YEAR MONTH DAY HOUR MINUTE SECOND ISO_TIMESTAMP < <(
    date '+%Y %m %d %H %M %S %Y-%m-%dT%H:%M:%S%z'
)

# Encode DAYHHMMSS as one unsigned integer. Arithmetic removes any leading zero
# while retaining zero padding inside the time portion.
MONTH_NUMBER=$((10#$MONTH))
RELEASE_SEQUENCE=$((10#$DAY * 1000000 + 10#$HOUR * 10000 + 10#$MINUTE * 100 + 10#$SECOND))
TAG="v${YEAR}.${MONTH_NUMBER}.${RELEASE_SEQUENCE}"

git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null &&
    die "tag already exists locally: $TAG"

COMMIT="$(git rev-parse HEAD)"
MESSAGE="Formative SV08 configuration release

Timestamp: $ISO_TIMESTAMP
Commit: $COMMIT"

printf 'Creating annotated tag %s\n' "$TAG"
git tag -a "$TAG" -m "$MESSAGE"

printf 'Pushing %s to origin\n' "$TAG"
if ! git push origin "refs/tags/$TAG"; then
    printf 'Push failed. The local tag was retained; retry with:\n' >&2
    printf '  git push origin refs/tags/%s\n' "$TAG" >&2
    exit 1
fi

printf 'Published %s\n' "$TAG"
printf '%s\n' "$MESSAGE"
