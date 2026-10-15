#!/bin/sh
# setup_worktree.sh [path] [branch]: create (or update) the grind worktree, by default
# /Users/ebenupton/elite-grind on branch "grind", at the main repo's current master HEAD.
# An existing worktree is reset to master HEAD only if it has no uncommitted changes
# and its branch has no commits master lacks (else it is left alone, with a message).
set -e
REPO=/Users/ebenupton/elite
WT=${1:-/Users/ebenupton/elite-grind}
BR=${2:-grind}
BASE=$(git -C "$REPO" rev-parse master)
if [ -e "$WT/.git" ]; then
    if [ -n "$(git -C "$WT" status --porcelain)" ]; then
        echo "$WT has uncommitted changes: left as is (at $(git -C "$WT" rev-parse --short HEAD))"; exit 0
    fi
    if [ -n "$(git -C "$REPO" rev-list "master..$BR" 2>/dev/null)" ]; then
        echo "branch $BR has commits not on master: left as is"; exit 0
    fi
    git -C "$WT" checkout -q "$BR"
    git -C "$WT" reset -q --hard "$BASE"
    echo "updated $WT ($BR) to master $(git -C "$REPO" rev-parse --short master)"
else
    if git -C "$REPO" show-ref -q --verify "refs/heads/$BR"; then
        if [ -n "$(git -C "$REPO" rev-list "master..$BR")" ]; then
            git -C "$REPO" worktree add -q "$WT" "$BR"
            echo "created $WT on existing branch $BR (has its own commits; not reset)"; exit 0
        fi
        git -C "$REPO" branch -f "$BR" "$BASE"
        git -C "$REPO" worktree add -q "$WT" "$BR"
    else
        git -C "$REPO" worktree add -q -b "$BR" "$WT" "$BASE"
    fi
    echo "created $WT on branch $BR at master $(git -C "$REPO" rev-parse --short master)"
fi
# the worktree's build.sh wants tools/beebasm (tracked?) -- make sure it is there
[ -x "$WT/tools/beebasm" ] || cp "$REPO/tools/beebasm" "$WT/tools/beebasm"
