#!/bin/sh
set -eu

scripts_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
ios="$scripts_dir/../submodules/telegram-ios"
patch="$scripts_dir/telegram-ios-macos.patch"
taugram_patch="$scripts_dir/telegram-ios-taugram.patch"

if [ ! -f "$ios/submodules/TelegramVoip/Package.swift" ]; then
    printf 'Initialize the telegram-ios submodule before preparing the macOS build.\n' >&2
    exit 1
fi

apply_forward() {
    [ -s "$1" ] || return 0
    if git -C "$ios" apply --reverse --check "$1" 2>/dev/null; then
        return 0
    fi
    git -C "$ios" apply --whitespace=nowarn "$1"
}

apply_reverse() {
    [ -s "$1" ] || return 0
    if git -C "$ios" apply --check "$1" 2>/dev/null; then
        return 0
    fi
    git -C "$ios" apply --whitespace=nowarn --reverse "$1"
}

case "$#:${1:-}" in
    0:)
        apply_forward "$patch"
        if ! apply_forward "$taugram_patch"; then
            printf 'scripts/telegram-ios-taugram.patch does not apply to this telegram-ios revision; merge it with: sh scripts/taugram-core-patch.sh apply\n' >&2
            exit 1
        fi
        ;;
    1:--reverse)
        apply_reverse "$taugram_patch"
        apply_reverse "$patch"
        ;;
    *)
        printf 'Usage: %s [--reverse]\n' "$0" >&2
        exit 2
        ;;
esac
