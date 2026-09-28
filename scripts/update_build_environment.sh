#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
PARENT_ROOT="${PROJECT_ROOT:h}"
OUTPUT_FILE="${PROJECT_ROOT}/BUILD_ENVIRONMENT.md"
TEMP_FILE="${OUTPUT_FILE}.tmp"

command_version() {
    local command_name="$1"
    shift

    if command -v "${command_name}" >/dev/null 2>&1; then
        "$@" 2>&1 || print -- "未能读取版本"
    else
        print -- "未安装或不可用"
    fi
}

git_value() {
    local repository="$1"
    shift

    if [[ -d "${repository}/.git" ]]; then
        git -C "${repository}" "$@" 2>/dev/null || print -- "未能读取"
    else
        print -- "未找到仓库"
    fi
}

package_resolved_files=()
for package_file in \
    "${PROJECT_ROOT}/Package.resolved" \
    "${PROJECT_ROOT}/.swiftpm/configuration/Package.resolved"; do
    if [[ -f "${package_file}" ]]; then
        package_resolved_files+=("${package_file}")
    fi
done

{
    print -- "# 构建环境"
    print --
    print -- '> 此文件由 `scripts/update_build_environment.sh` 自动生成。'
    print -- "> 更新时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
    print --
    print -- "## 工具版本"
    print --
    print -- "- macOS：$(command_version sw_vers sw_vers -productVersion)"
    print -- "- Xcode：$(command_version xcodebuild xcodebuild -version | tr '\\n' '; ' | sed 's/; $//')"
    print -- "- Swift：$(command_version swift swift --version | head -1)"
    print -- "- iOS SDK：$(command_version xcrun xcrun --sdk iphoneos --show-sdk-version)"
    print -- "- macOS SDK：$(command_version xcrun xcrun --sdk macosx --show-sdk-version)"
    print --
    print -- "## Readium Fork"
    print --
    print -- '- 仓库：`swift-toolkit-macos`（当前仓库根目录）'
    print -- "- 分支：$(git_value "${PROJECT_ROOT}" branch --show-current)"
    print -- "- Commit：$(git_value "${PROJECT_ROOT}" rev-parse HEAD)"
    print -- "- 最近提交：$(git_value "${PROJECT_ROOT}" log -1 --oneline)"
    print --
    print -- "### Git Remote"
    print --
    print -- "- origin：$(git_value "${PROJECT_ROOT}" config --get remote.origin.url)"
    print -- "- upstream：$(git_value "${PROJECT_ROOT}" config --get remote.upstream.url)"
    print --
    print -- "## Swift Package 信息"
    print --

    print -- "- Swift tools version：$(sed -n 's#^// swift-tools-version:\(.*\)#\1#p' "${PROJECT_ROOT}/Package.swift" | head -1)"
    print -- "- Package.swift platforms：$(sed -n 's#^[[:space:]]*platforms: \(.*\),#\1#p' "${PROJECT_ROOT}/Package.swift" | head -1)"
    print --

    if (( ${#package_resolved_files} == 0 )); then
        print -- '未找到 `Package.resolved`；以下为 `Package.swift` 中声明的依赖范围：'
        print --
        print -- '```text'
        grep -E '^[[:space:]]*\.package\(url:' "${PROJECT_ROOT}/Package.swift" \
            | sed 's/^[[:space:]]*//' || true
        print -- '```'
    else
        for package_file in "${package_resolved_files[@]}"; do
            relative_file="${package_file#${PROJECT_ROOT}/}"
            print -- "### ${relative_file}"
            print --
            print -- '```text'
            sed -n '/"pins"[[:space:]]*:/,/^[[:space:]]*]/p' "${package_file}" \
                | grep -E '"identity"|"location"|"version"|"revision"' \
                | sed 's/^[[:space:]]*//' || true
            print -- '```'
            print --
        done
    fi
} > "${TEMP_FILE}"

mv "${TEMP_FILE}" "${OUTPUT_FILE}"
print -- '已刷新：BUILD_ENVIRONMENT.md'