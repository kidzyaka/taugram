#!/bin/sh
set -eu

scripts_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
root="$(CDPATH= cd "$scripts_dir/.." && pwd)"
ios="$root/submodules/telegram-ios"
macos_patch="$scripts_dir/telegram-ios-macos.patch"
taugram_patch="$scripts_dir/telegram-ios-taugram.patch"

usage() {
    cat >&2 <<EOF
usage: scripts/taugram-core-patch.sh export|apply|check

  export  write the Taugram changes in submodules/telegram-ios, taken on top of
          telegram-ios-macos.patch, to scripts/telegram-ios-taugram.patch
  apply   apply both patches; when the Taugram patch no longer applies after a
          submodule update, merge it three-way and leave conflict markers
  check   fail when the patch file is out of date or the submodule pointer is
          not an upstream commit; run it before every commit
EOF
    exit 2
}

die() {
    printf '%s\n' "$*" >&2
    exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ios_git() {
    git -C "$ios" "$@"
}

require_submodule() {
    [ -f "$ios/submodules/TelegramCore/Package.swift" ] ||
        die "Initialize the submodule first: git submodule update --init --recursive submodules/telegram-ios"
}

require_xcode27_reverted() {
    if grep -q ImplicitStrongCapture "$ios/submodules/TelegramCore/Package.swift" ||
        ! grep -q '\.metal")' "$ios/submodules/MetalEngine/Package.swift"; then
        die "The Xcode 27 changes are applied inside submodules/telegram-ios and would end up in the patch. Run scripts/xcode27.sh revert first and scripts/xcode27.sh apply afterwards."
    fi
}

require_macos_patch_applied() {
    ios_git apply --summary "$macos_patch" | sed -n 's/^ create mode [0-7]* //p' > "$tmp/created"
    while IFS= read -r path; do
        [ -e "$ios/$path" ] ||
            die "telegram-ios-macos.patch is not applied (missing $path). Run sh scripts/prepare-telegram-ios.sh first."
    done < "$tmp/created"
}

copy_index() {
    cp "$(ios_git rev-parse --path-format=absolute --git-path index)" "$1"
}

base_tree() {
    GIT_INDEX_FILE="$tmp/base.index" ios_git read-tree HEAD
    GIT_INDEX_FILE="$tmp/base.index" ios_git apply --cached --whitespace=nowarn "$macos_patch"
    GIT_INDEX_FILE="$tmp/base.index" ios_git write-tree
}

work_tree() {
    copy_index "$tmp/work.index"
    GIT_INDEX_FILE="$tmp/work.index" ios_git add -A
    GIT_INDEX_FILE="$tmp/work.index" ios_git write-tree
}

write_patch() {
    require_submodule
    require_xcode27_reverted
    require_macos_patch_applied
    base="$(base_tree)"
    work="$(work_tree)"
    ios_git diff --binary --full-index --ignore-submodules=all "$base" "$work" > "$1"
    if grep -qE '^\+(<<<<<<<|>>>>>>>)( |$)' "$1"; then
        die "Conflict markers are still in submodules/telegram-ios; resolve them before exporting."
    fi
}

print_summary() {
    if [ -s "$1" ]; then
        ios_git apply --stat "$1"
    else
        echo "no Taugram changes in submodules/telegram-ios"
    fi
}

export_patch() {
    write_patch "$tmp/taugram.patch"
    cp "$tmp/taugram.patch" "$taugram_patch"
    print_summary "$taugram_patch"
    echo "wrote scripts/telegram-ios-taugram.patch"
}

check_pointer() {
    head="$(ios_git rev-parse HEAD)"
    staged="$(git -C "$root" ls-files -s submodules/telegram-ios | awk '{ print $2 }')"
    [ "$head" = "$staged" ] ||
        die "submodules/telegram-ios is at $head but the superproject records $staged. Stage the submodule bump together with the refreshed patch."
    [ -n "$(ios_git for-each-ref --contains HEAD --count=1 refs/remotes refs/tags)" ] ||
        die "submodules/telegram-ios is at $head, which no upstream branch or tag contains. Never commit inside the submodule: keep Taugram's core changes in scripts/telegram-ios-taugram.patch."
}

check_patch() {
    check_pointer
    write_patch "$tmp/current.patch"
    [ -f "$taugram_patch" ] && cmp -s "$tmp/current.patch" "$taugram_patch" ||
        die "scripts/telegram-ios-taugram.patch does not match submodules/telegram-ios. Run sh scripts/taugram-core-patch.sh export and stage the patch."
    echo "scripts/telegram-ios-taugram.patch is up to date"
}

apply_patches() {
    require_submodule
    if ! ios_git apply --reverse --check "$macos_patch" 2>/dev/null; then
        ios_git apply --whitespace=nowarn "$macos_patch"
    fi
    if [ ! -s "$taugram_patch" ]; then
        echo "scripts/telegram-ios-taugram.patch is empty, nothing to apply"
        return
    fi
    if ios_git apply --reverse --check "$taugram_patch" 2>/dev/null; then
        echo "scripts/telegram-ios-taugram.patch is already applied"
        return
    fi
    if ios_git apply --whitespace=nowarn "$taugram_patch" 2>/dev/null; then
        echo "applied scripts/telegram-ios-taugram.patch"
        return
    fi
    copy_index "$tmp/merge.index"
    GIT_INDEX_FILE="$tmp/merge.index" ios_git add -A
    if GIT_INDEX_FILE="$tmp/merge.index" ios_git apply --3way --whitespace=nowarn "$taugram_patch"; then
        echo "merged scripts/telegram-ios-taugram.patch three-way; build, then run sh scripts/taugram-core-patch.sh export"
        return
    fi
    conflicts="$(GIT_INDEX_FILE="$tmp/merge.index" ios_git diff --name-only --diff-filter=U)"
    [ -n "$conflicts" ] ||
        die "The patch could not be merged: the blobs it was made from are not in this clone. Apply it with git -C submodules/telegram-ios apply --reject scripts/telegram-ios-taugram.patch and fix the .rej hunks by hand."
    printf 'Resolve the conflict markers in submodules/telegram-ios:\n%s\nthen run sh scripts/taugram-core-patch.sh export\n' "$conflicts" >&2
    exit 1
}

case "${1:-}" in
    export) export_patch ;;
    apply) apply_patches ;;
    check) check_patch ;;
    *) usage ;;
esac
