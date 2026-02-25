#!/bin/bash

# 用法:
#   ./fix_repo_sync_infinite.sh [可选: extra_project_name]
# 功能:
#   无限循环运行 repo sync，自动检测并删除损坏/缺失仓库目录，
#   直到同步完全成功（或手动 Ctrl+C 终止）。

set -e

attempt=1

while true; do
    echo "=== 第 ${attempt} 次尝试同步（无限循环，直到成功） ==="

    sync_output=$(repo sync -c -j8 --force-sync --no-clone-bundle 2>&1 || true)
    echo "$sync_output" | tail -30

    # 1) GitError: project_name ...
    giterror_projects=$(echo "$sync_output" | grep -i "GitError" | sed -n 's/.*GitError: \([^ ]*\) .*/\1/p')

    # 2) project xxx/ missing
    missing_projects=$(echo "$sync_output" | grep " missing" | sed -n 's/.*project \([^ ]*\)\/.*/\1/p')

    all_bad_projects=$(echo -e "$giterror_projects\n$missing_projects" | sort -u | grep -v '^$' || true)

    if [ -z "$all_bad_projects" ]; then
        echo "=== 同步完全成功！无损坏/缺失仓库 ==="
        break
    fi

    echo "检测到问题仓库:"
    echo "$all_bad_projects"

    for proj in $all_bad_projects; do
        path="$proj"

        # 如果 name != path，尝试从 manifest 反查 path
        if [ ! -d "$path" ]; then
            path=$(grep -r "<project.*name=\"${proj}\"" .repo/manifests/ .repo/manifest.xml 2>/dev/null \
                | sed -n 's/.*path="\([^"]*\)".*/\1/p' | head -1)
        fi

        if [ -n "$path" ] && [ -d "$path" ]; then
            echo "删除问题目录: $path"
            rm -rf "$path"
        else
            echo "警告: 未找到有效路径 $proj，跳过"
        fi
    done

    # 可选参数：额外强制删除
    if [ -n "$1" ]; then
        extra_proj="$1"
        extra_path=$(grep -r "<project name=\"${extra_proj}\"" .repo/manifests/ .repo/manifest.xml 2>/dev/null \
            | sed -n 's/.*path="\([^"]*\)".*/\1/p' | head -1)
        if [ -n "$extra_path" ] && [ -d "$extra_path" ]; then
            echo "参数指定删除: $extra_path"
            rm -rf "$extra_path"
        fi
    fi

    attempt=$((attempt + 1))
    echo "准备下一次循环..."
    sleep 2
done

echo "最终检查:"
repo status || true
repo sync -c -j8
echo "全部完成！仓库已干净。"

