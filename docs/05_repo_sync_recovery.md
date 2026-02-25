# repo sync 异常自动修复

本文档用于处理 `repo sync` 时常见的仓库损坏/缺失问题，尤其是以下报错：

```text
error.GitError: js_api_module rev-list ... fatal: not a git repository ...
```

## 1. 手工定位与删除（单个项目）

当看到报错项目名（例如 `js_api_module`）后，可先确认 manifest 映射：

```bash
grep -r "js_api_module" .repo/manifests/
```

示例输出：

- `.repo/manifests/default.xml: <project name="js_api_module" path="base/compileruntime/js_api_module"/>`

删除损坏目录：

```bash
rm -rf ./base/compileruntime/js_api_module/
```

然后重新执行：

```bash
repo sync -c
```

## 2. 批量自动修复脚本（推荐）

仓库内置脚本：`scripts/fix_repo_sync_infinite.sh`  
功能：无限循环执行 `repo sync`，自动识别并删除损坏/缺失项目目录，直到同步成功。

执行方式：

```bash
cd /home/openharmony
bash ohos-sglintx/scripts/fix_repo_sync_infinite.sh
```

可选：额外强制删除某个项目（参数传 `project name`）：

```bash
bash ohos-sglintx/scripts/fix_repo_sync_infinite.sh js_api_module
```

## 3. 同步完成后建议执行

```bash
repo forall -c 'git lfs pull'
bash build/prebuilts_download.sh
```

## 4. `prebuilts_download.sh` 常见失败处理

如果 `build/prebuilts_download.sh` 失败，建议：

1. 先看日志，定位失败目录和具体 SHA/包名。
2. 进入对应目录后清理缓存（常见是 npm/pnpm 缓存问题）。
3. 手动安装缺失依赖后回到根目录重试脚本。

常见命令：

```bash
npm cache clean --force
```

如果你不确定具体怎么修，直接把报错日志（`cat` 输出）交给 AI，按日志逐项修复效率最高。

