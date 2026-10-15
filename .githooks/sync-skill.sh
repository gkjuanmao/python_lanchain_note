#!/bin/sh
# 把仓库里的 SKILL.md 同步到各 agent 的 skills 目录（ZCode、Trae、DSH）。
# 仓库副本是唯一的版本源；目标目录里只是副本，不要直接改那边。
set -u

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$REPO_ROOT" || exit 0

# 默认同步到 ZCode、Trae 的用户级 skills 目录，以及 DSH 的项目级 skills 目录：
# DSH 只扫描 <项目根>/.dsh/skills/<name>/SKILL.md 或 <name>.md，仓库根那份它读不到。
# 可用 ZCODE_SKILLS_HOME 覆盖（多个用空格分隔）
USER_HOME="${HOME:-/c/Users/Administrator}"
SKILLS_HOMES="${ZCODE_SKILLS_HOME:-$USER_HOME/.zcode/skills $USER_HOME/.trae/skills $REPO_ROOT/.dsh/skills}"

# 按 git 跟踪记录查找，所以 SKILL.md 挪到哪一层都能找到
MATCHES=$(git ls-files | grep -E '(^|/)SKILL\.md$' || true)
if [ -z "$MATCHES" ]; then
    echo "⚠ skill 未同步：仓库里找不到被 git 跟踪的 SKILL.md" >&2
    exit 0
fi

echo "$MATCHES" | while IFS= read -r SRC; do
    [ -f "$SRC" ] || continue

    # 目标文件夹名优先取 frontmatter 的 name 字段，其次取所在目录名
    SKILL_NAME=$(sed -n '/^---[[:space:]]*$/,/^---[[:space:]]*$/p' "$SRC" \
        | sed -n 's/^name:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' \
        | head -n 1)
    if [ -z "$SKILL_NAME" ]; then
        DIR=$(dirname "$SRC")
        if [ "$DIR" = "." ]; then
            echo "⚠ 跳过 $SRC：既没有 name 字段，又位于仓库根目录，无法推断 skill 名称" >&2
            continue
        fi
        SKILL_NAME=$(basename "$DIR")
    fi

    for SKILLS_HOME in $SKILLS_HOMES; do
        DEST_DIR="$SKILLS_HOME/$SKILL_NAME"
        DEST="$DEST_DIR/SKILL.md"

        # 内容一致就不动了，避免每次提交都重写文件
        if [ -f "$DEST" ] && cmp -s "$SRC" "$DEST"; then
            continue
        fi

        mkdir -p "$DEST_DIR" || continue
        cp "$SRC" "$DEST" || continue

        echo "→ 已同步 skill: $DEST"
    done
done

exit 0
