#!/usr/bin/env bash

# publishes GITHUB_SHA as the next vMAJOR.MINOR.PATCH release of GITHUB_REPOSITORY, the bump decided by the
# commits since the latest release: a breaking change is major, a feat is minor, anything else is patch

set -euo pipefail

release_tags() {
    git tag --list 'v*' | { grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true; }
}

if git tag --points-at "$GITHUB_SHA" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "$GITHUB_SHA is already released"
    exit 0
fi

latest=$(release_tags | sort -V | tail -n 1)
range=${latest:+$latest..}$GITHUB_SHA
if [ -z "$(git rev-list "$range")" ]; then
    echo "nothing new since $latest"
    exit 0
fi

subjects=$(git log --format=%s "$range")
bodies=$(git log --format=%b "$range")
if grep -qE '^[a-z]+(\([^)]*\))?!:' <<< "$subjects" || grep -qE '^BREAKING[ -]CHANGE:' <<< "$bodies"; then
    bump="major"
elif grep -qE '^feat(\([^)]*\))?:' <<< "$subjects"; then
    bump="minor"
else
    bump="patch"
fi

IFS=. read -r major minor patch <<< "${latest#v}"
major=${major:-0} minor=${minor:-0} patch=${patch:-0}
case $bump in
    major) tag="v$((major + 1)).0.0" ;;
    minor) tag="v$major.$((minor + 1)).0" ;;
    patch) tag="v$major.$minor.$((patch + 1))" ;;
esac

# the notes are the merged pull requests' descriptions, or the commit subjects when nothing was merged through one
mapfile -t pulls < <(git rev-list --first-parent "$range" \
    | while read -r sha; do gh api "repos/$GITHUB_REPOSITORY/commits/$sha/pulls" --jq '.[].number'; done \
    | awk '!seen[$0]++')
notes=$(mktemp)
if [ "${#pulls[@]}" -eq 0 ]; then
    git log --format='* %s' "$range" > "$notes"
elif [ "${#pulls[@]}" -eq 1 ]; then
    { gh api "repos/$GITHUB_REPOSITORY/pulls/${pulls[0]}" --jq '.body // ""'; printf '\n#%s\n' "${pulls[0]}"; } > "$notes"
else
    for number in "${pulls[@]}"; do
        printf '## %s (#%s)\n\n' "$(gh api "repos/$GITHUB_REPOSITORY/pulls/$number" --jq .title)" "$number"
        gh api "repos/$GITHUB_REPOSITORY/pulls/$number" --jq '.body // ""'
        printf '\n'
    done > "$notes"
fi

gh release create "$tag" --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" --title "$tag" --notes-file "$notes"
echo "released $GITHUB_SHA as $tag ($bump, since ${latest:-the start})"
