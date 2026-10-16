#!/bin/sh
# setup_worktree.sh [path] [branch] [base]: create, or reset, a grind worktree for full
# Master Elite: by default /Users/ebenupton/elite-full-grind on branch full-grind, at
# base = full-master's current HEAD.
#
# An existing worktree is reset to the base only if it has no uncommitted changes and
# its branch has no commits the base lacks (else it is left alone, with a message: a
# grind branch with work on it is never thrown away).  A missing worktree is created
# (an existing branch with no commits of its own is moved to the base first; one with
# its own commits is checked out as it is).  Refs are shared by every worktree of the
# repository this script is in.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
WT=${1:-/Users/ebenupton/elite-full-grind}
BR=${2:-full-grind}
BASEREF=${3:-full-master}
G="git -C $HERE"
BASE=$($G rev-parse --verify "$BASEREF^{commit}")
SHORT=$($G rev-parse --short "$BASE")
if [ -e "$WT/.git" ]; then
    if [ -n "$(git -C "$WT" status --porcelain --untracked-files=no)" ]; then
        echo "$WT has uncommitted changes: left as is (at $(git -C "$WT" rev-parse --short HEAD))"; exit 0
    fi
    if $G show-ref -q --verify "refs/heads/$BR" && [ -n "$($G rev-list "$BASE..$BR")" ]; then
        echo "branch $BR has commits not on $BASEREF: left as is (merge them into $BASEREF first)"; exit 0
    fi
    CUR=$(git -C "$WT" rev-parse --abbrev-ref HEAD)
    if [ "$CUR" != "$BR" ]; then
        if $G show-ref -q --verify "refs/heads/$BR"; then git -C "$WT" checkout -q "$BR"
        else git -C "$WT" checkout -q -b "$BR"; fi
    fi
    git -C "$WT" reset -q --hard "$BASE"
    echo "reset $WT ($BR) to $BASEREF $SHORT"
else
    if $G show-ref -q --verify "refs/heads/$BR"; then
        if [ -n "$($G rev-list "$BASE..$BR")" ]; then
            $G worktree add -q "$WT" "$BR"
            echo "created $WT on existing branch $BR (has its own commits; not reset)"; exit 0
        fi
        $G branch -f "$BR" "$BASE"
        $G worktree add -q "$WT" "$BR"
    else
        $G worktree add -q -b "$BR" "$WT" "$BASE"
    fi
    echo "created $WT on branch $BR at $BASEREF $SHORT"
fi
