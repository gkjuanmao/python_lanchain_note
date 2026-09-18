#!/bin/sh
# 把仓库里的 SKILL.md 同步到用户级 skills 目录，供 ZCode 加载。
# 仓库副本是唯一的版本源；用户级目录里只是副本，不要直接改那边。
set -u

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
SRC="$REPO_ROOT/SKILL.md"

[ -f "$SRC" ] || exit 0

# 目标文件夹名取自 frontmatter 的 name 字段，这样 skill 改名后会自动同步到新位置
SKILL_NAME=$(sed -n '/^---[[:space:]]*$/,/^---[[:space:]]*$/p' "$SRC" \
    | sed -n 's/^name:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' \
    | head -n 1)
[ -n "$SKILL_NAME" ] || SKILL_NAME="obsidian-organizer"

SKILLS_HOME="${ZCODE_SKILLS_HOME:-${HOME:-/c/Users/Administrator}/.zcode/skills}"
DEST_DIR="$SKILLS_HOME/$SKILL_NAME"
DEST="$DEST_DIR/SKILL.md"

# 内容一致就不动了，避免每次提交都重写文件
if [ -f "$DEST" ] && cmp -s "$SRC" "$DEST"; then
    exit 0
fi

mkdir -p "$DEST_DIR" || exit 0
cp "$SRC" "$DEST" || exit 0

echo "→ 已同步 skill: $DEST"
exit 0
