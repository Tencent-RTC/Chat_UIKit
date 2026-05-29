#!/usr/bin/env bash
###############################################################################
# publish_pods.sh
# 一键批量发布 TUIKit 系列 podspec 到 CocoaPods Trunk，并把 Trunk 上对应的
# 源码 zip 同步回本地 Swift/TUIKit/<module_name>/。
#
# 通过直接调用 Trunk HTTP API (`pod ipc spec` -> `curl POST`) 来绕开
# `pod trunk push` 本地 xcodebuild 校验，适合在源码或 podspec 已知能跑、
# 但本地校验过于严格（如 Xcode 26 + iOS API 检查 + SnapKit import 缺失等）
# 的场景下「强推」发布。
#
# 推送成功后，会做两件事:
#  1) 始终把 Swift/TUIKit/<module_name>/<Pod>.podspec 中的 spec.version
#     回写为刚发布的版本号 (xcframework 二进制 pod 没有本地 podspec, 会跳过);
#  2) 若 SYNC_SOURCE=1 (默认), 再从 spec.source 下载 zip 解压, 用其内容
#     覆盖 Swift/TUIKit/<module_name>/ 下的源码文件, 同时保留并刷新本地的
#     <Pod>.podspec. xcframework 二进制 zip 会自动跳过该步骤.
#
# 脚本位置: <repo>/Swift/Podspec/publish_pods.sh
# (与各 .podspec 同目录; 可在任意 cwd 下执行, 路径会按脚本位置自动解析)
#
# 用法:
#   ./Swift/Podspec/publish_pods.sh            # 用脚本里默认的 pod 列表
#   ./publish_pods.sh TUICore TIMCommon_Swift  # 只发指定的 pod
#   ./publish_pods.sh -v 8.9.7600              # 先把所有 podspec 版本更新到
#                                              # 8.9.7600 (spec.version + source
#                                              # URL + 依赖 ~> 约束), 再发布
#   ./publish_pods.sh -v 8.9.7600 TUICore      # 只更新并发布指定 pod
#   SET_VERSION=8.9.7600 ./publish_pods.sh     # 同 -v, 用环境变量传入
#   VERSION=8.9.7600 ./publish_pods.sh         # 仅"校验"版本号一致 (不修改文件)
#   SYNC_SOURCE=0 ./publish_pods.sh            # 仅发布，不回同步本地源码
#   SKIP_PUBLISH=1 ./publish_pods.sh           # 仅回同步源码，不再推送 Trunk
#   ./publish_pods.sh --update-podfile         # 发布后把 TUIKitDemo/Podfile 里相关
#                                              # pod 版本更新到本次发布版本 + pod install
#   ./publish_pods.sh --verify-build           # 发布后 pod install 并编译验证 TUIKitDemo
#   ./publish_pods.sh --update-podfile --no-pod-install  # 只改 Podfile, 不 pod install
#   # 上述开关也可用环境变量: UPDATE_PODFILE / RUN_POD_INSTALL / VERIFY_BUILD
#   # 编译配置: DEMO_SCHEME / DEMO_WORKSPACE / DEMO_DESTINATION
#
# 注意: -v 会把版本号统一改成输入值 (含 TXIMSDK_Plus_* 系列)。请确保对应版本的
#       下载包在 CDN 上确实存在, 否则发布或源码回同步会因下载失败而报错。
#
# 依赖:
#   - cocoapods (pod ipc spec)
#   - curl, awk, grep, unzip, sed
#   - ~/.netrc 里配置好 trunk.cocoapods.org 的 password (Token)
#     可通过 `pod trunk register <email>` 取得
#
# 退出码:
#   0  全部成功
#   1  有 pod 推送失败 (重试 5 次仍未确认) 或源码同步失败
###############################################################################

set -uo pipefail

# ---- 配置 ----------------------------------------------------------------
# 本脚本位于 <repo>/Swift/Podspec/ 下:
#   SCRIPT_DIR  = <repo>/Swift/Podspec      (= PODSPEC_DIR)
#   REPO_ROOT   = <repo>
#   TUIKIT_DIR  = <repo>/Swift/TUIKit
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PODSPEC_DIR="$SCRIPT_DIR"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TUIKIT_DIR="${REPO_ROOT}/Swift/TUIKit"
DEMO_DIR="${REPO_ROOT}/Swift/TUIKitDemo"
PODFILE="${DEMO_DIR}/Podfile"
NETRC_HOST="trunk.cocoapods.org"
TRUNK_API="https://trunk.cocoapods.org/api/v1/pods?allow_warnings=true"
COCOAPODS_UA="CocoaPods/1.16.2"
MAX_ATTEMPTS=5
RETRY_INTERVAL=10
HTTP_TIMEOUT=60
DOWNLOAD_TIMEOUT=300

# 回同步开关 (1 开 / 0 关)
SYNC_SOURCE="${SYNC_SOURCE:-1}"
# 是否跳过 Trunk 推送 (调试同步逻辑时用)
SKIP_PUBLISH="${SKIP_PUBLISH:-0}"

# 发布完成后, 是否把 TUIKitDemo/Podfile 里相关 pod 的版本更新到本次发布版本 (1 开 / 0 关)
UPDATE_PODFILE="${UPDATE_PODFILE:-0}"
# 更新 Podfile 后是否自动 pod install (1 开 / 0 关)
RUN_POD_INSTALL="${RUN_POD_INSTALL:-1}"
# 是否编译验证 TUIKitDemo (1 开 / 0 关; 开启会自动先 pod install)
VERIFY_BUILD="${VERIFY_BUILD:-0}"
# 编译验证相关配置
DEMO_WORKSPACE="${DEMO_WORKSPACE:-TUIKitDemo.xcworkspace}"
DEMO_SCHEME="${DEMO_SCHEME:-TUIKitDemo}"
DEMO_DESTINATION="${DEMO_DESTINATION:-generic/platform=iOS Simulator}"

# 默认发布顺序 (IM SDK 基础库 -> TUIKit 核心库 -> 业务库 -> 插件)
DEFAULT_PODS=(
  "TXIMSDK_Plus_iOS"
  "TXIMSDK_Plus_iOS_XCFramework"
  "TXIMSDK_Plus_Swift_iOS"
  "TXIMSDK_Plus_Swift_iOS_XCFramework"
  "TXIMSDK_Plus_Swift_Vision_XCFramework"
  "TXIMSDK_Plus_QuicPlugin"
  "TXIMSDK_Plus_QuicPlugin_XCFramework"
  "TXIMSDK_Plus_AdvancedEncryptionPlugin"
  "TXIMSDK_Plus_Mac"
  "TUICore"
  "TIMCommon_Swift"
  "TUIChat_Swift"
  "TUIConversation_Swift"
  "TUIContact_Swift"
  "TUISearch_Swift"
  "TUIGroupNotePlugin_Swift"
  "TUIPollPlugin_Swift"
  "TUITextToVoicePlugin_Swift"
  "TUIVoiceToTextPlugin_Swift"
  "TUITranslationPlugin_Swift"
  "TUIEmojiPlugin_Swift"
  "TUIOfficialAccountPlugin_Swift"
  "TUIConversationGroupPlugin_Swift"
  "TUIConversationMarkPlugin_Swift"
  "TIMPush"
  "TPush"
)
# --------------------------------------------------------------------------

# 着色输出
if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_BLU=$'\033[34m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_DIM=""; C_RST=""
fi
log_step() { printf "\n${C_BLU}==> %s${C_RST}\n" "$*"; }
log_ok()   { printf "${C_GRN}[OK]${C_RST}   %s\n" "$*"; }
log_warn() { printf "${C_YLW}[WARN]${C_RST} %s\n" "$*"; }
log_err()  { printf "${C_RED}[FAIL]${C_RST} %s\n" "$*"; }
log_dim()  { printf "${C_DIM}%s${C_RST}\n" "$*"; }

# ---- podspec 解析 ---------------------------------------------------------

# 解析 podspec 中形如  spec.<field> = '<value>'  的字段
# 用法: podspec_field <podspec> <field>
podspec_field() {
  local podspec="$1" field="$2"
  grep -m1 -E "^[[:space:]]*spec\.${field}[[:space:]]*=" "$podspec" 2>/dev/null \
    | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/"
}

# 取 module_name (没有则退回 name)
podspec_module_name() {
  local podspec="$1"
  local m
  m=$(podspec_field "$podspec" "module_name")
  [[ -z "$m" ]] && m=$(podspec_field "$podspec" "name")
  echo "$m"
}

# 取 spec.source 中的 http(s) URL
podspec_source_url() {
  local podspec="$1"
  grep -m1 -E "^[[:space:]]*spec\.source[[:space:]]*=" "$podspec" 2>/dev/null \
    | grep -oE "https?://[^'\"]+" \
    | head -1
}

# sed -i -E 包装 (兼容 GNU / BSD sed)
# 用法: _sed_inplace <sed表达式> <文件>
_sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i -E "$1" "$2"
  else
    sed -i '' -E "$1" "$2"
  fi
}

# 把 podspec 里的 spec.version 改成给定值 (兼容 GNU / BSD sed)
bump_podspec_version() {
  local podspec="$1" new_version="$2"
  [[ -z "$new_version" || ! -f "$podspec" ]] && return 0
  _sed_inplace \
    "s/(spec\.version[[:space:]]*=[[:space:]]*)['\"][^'\"]*['\"]/\1'${new_version}'/" \
    "$podspec"
}

# 把 podspec 三处版本号统一改成 new_version:
#   1) spec.version
#   2) spec.source 下载 URL 里的 x.y.z 版本段 (URL 里只会出现该 pod 自身版本)
#   3) 依赖版本约束 (~>, >=, >, <=, <, ==) 中"等于旧版本"的部分
#      只替换与旧版本完全一致的约束, 避免误伤 SnapKit / AlbumPicker 等三方库
# 返回:
#   0 成功 / 1 入参非法或文件不存在
bump_podspec_all() {
  local podspec="$1" new_version="$2"
  [[ -z "$new_version" || ! -f "$podspec" ]] && return 1

  local old_version
  old_version=$(podspec_field "$podspec" "version")

  # 1) spec.version
  bump_podspec_version "$podspec" "$new_version"

  # 2) source URL 里的版本段
  _sed_inplace \
    "/spec\.source[[:space:]]*=/ s/[0-9]+\.[0-9]+\.[0-9]+/${new_version}/g" \
    "$podspec"

  # 3) 依赖版本约束: 把"等于旧版本"的约束统一改到新版本
  #    (~> >= <= == > < 都覆盖; 仅当版本号==旧版本时才替换, 不动三方库)
  if [[ -n "$old_version" && "$old_version" != "$new_version" ]]; then
    local old_re="${old_version//./\\.}"
    _sed_inplace \
      "s/(~>|>=|<=|==|>|<)([[:space:]]*)${old_re}/\1\2${new_version}/g" \
      "$podspec"
  fi
  return 0
}

# 把 Swift/TUIKit/<module>/<pod>.podspec 的 spec.version 同步为发布版本
# (与源码同步解耦：即便没有发生源码替换也会执行，保证版本号始终一致)
#
# 返回:
#   0 已成功更新
#   1 更新失败
#   2 跳过 (找不到本地 podspec)
bump_local_podspec() {
  local pod="$1"
  local pub_podspec="${PODSPEC_DIR}/${pod}.podspec"
  [[ -f "$pub_podspec" ]] || return 2

  local version module local_podspec old_version
  version=$(podspec_field "$pub_podspec" "version")
  module=$(podspec_module_name "$pub_podspec")
  [[ -z "$version" || -z "$module" ]] && return 2

  local_podspec="${TUIKIT_DIR}/${module}/${pod}.podspec"
  if [[ ! -f "$local_podspec" ]]; then
    log_dim "  ($pod 本地无 ${pod}.podspec，跳过版本号回写)"
    return 2
  fi

  old_version=$(podspec_field "$local_podspec" "version")
  if [[ "$old_version" == "$version" ]]; then
    log_dim "  (${pod} 本地 podspec 版本已是 ${version}，无需更新)"
    return 0
  fi

  if bump_podspec_version "$local_podspec" "$version"; then
    log_ok "${pod} 本地 podspec 版本 ${old_version} -> ${version}"
    return 0
  else
    log_err "${pod} 本地 podspec 版本回写失败 (${local_podspec})"
    return 1
  fi
}

# 读取 Trunk Token (~/.netrc)
get_trunk_token() {
  if [[ ! -f "$HOME/.netrc" ]]; then
    log_err "~/.netrc 不存在，请先执行 'pod trunk register <email>' 完成注册"
    exit 1
  fi
  local token
  token=$(awk -v host="$NETRC_HOST" '
    $1=="machine" && $2==host {flag=1; next}
    flag && $1=="machine" {flag=0}
    flag && $1=="password" {print $2; exit}
  ' "$HOME/.netrc")
  if [[ -z "$token" ]]; then
    log_err "未在 ~/.netrc 中找到 $NETRC_HOST 的 password (Token)"
    exit 1
  fi
  echo "$token"
}

# 推送单个 pod
push_pod() {
  local pod="$1"
  local token="$2"
  local podspec="${PODSPEC_DIR}/${pod}.podspec"
  local json="/tmp/${pod}.podspec.json"
  local resp="/tmp/${pod}.resp.txt"

  if [[ ! -f "$podspec" ]]; then
    log_err "找不到 podspec: $podspec"
    return 1
  fi

  log_step "Pushing: $pod"

  # 把 podspec 转 JSON
  if ! pod ipc spec "$podspec" > "$json" 2>/tmp/pod_ipc_err.txt; then
    log_err "pod ipc spec 失败:"
    cat /tmp/pod_ipc_err.txt
    return 1
  fi

  # 可选: 校验 JSON 里的 version 字段
  if [[ -n "${VERSION:-}" ]]; then
    local spec_ver
    spec_ver=$(grep -m1 '"version"' "$json" | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/')
    if [[ "$spec_ver" != "$VERSION" ]]; then
      log_warn "${pod} 的版本是 ${spec_ver}，但 VERSION=${VERSION}，已跳过"
      return 2
    fi
  fi

  local attempt http_code
  for ((attempt=1; attempt<=MAX_ATTEMPTS; attempt++)); do
    log_dim "  attempt ${attempt}/${MAX_ATTEMPTS} ..."
    http_code=$(curl -sS -X POST "$TRUNK_API" \
      -H "Content-Type: application/json; charset=utf-8" \
      -H "Accept: application/json; charset=utf-8" \
      -H "User-Agent: $COCOAPODS_UA" \
      -H "Authorization: Token $token" \
      --data-binary @"$json" \
      -o "$resp" \
      -w "%{http_code}" \
      --max-time $HTTP_TIMEOUT 2>/dev/null || echo "000")

    log_dim "  HTTP $http_code  $(cat "$resp" 2>/dev/null | head -c 200)"

    case "$http_code" in
      200|201|303)
        log_ok "$pod 推送成功"
        return 0
        ;;
      409)
        if grep -q "duplicate" "$resp" 2>/dev/null; then
          # 504/500 误判后的重试会变成 duplicate，说明上一次实际入库了
          log_ok "$pod 已存在 (上一次推送实际成功)"
          return 0
        fi
        ;;
      422)
        log_err "$pod 服务端拒绝 (422): $(cat "$resp")"
        return 1
        ;;
      401|403)
        if grep -q "Source code" "$resp" 2>/dev/null; then
          # 这是 Trunk 在校验 source url 时常见的偶发误报，可重试
          : # fallthrough to retry
        else
          log_err "$pod 未授权 / 禁止 (HTTP $http_code)"
          cat "$resp"
          return 1
        fi
        ;;
    esac

    if (( attempt < MAX_ATTEMPTS )); then
      log_dim "  retrying in ${RETRY_INTERVAL}s ..."
      sleep $RETRY_INTERVAL
    fi
  done

  log_err "$pod 推送失败 (重试 $MAX_ATTEMPTS 次仍未确认)"
  return 1
}

# ---- 同步源码 -------------------------------------------------------------
#
# 在推送成功后，从 spec.source 下载 zip，解压后替换 Swift/TUIKit/<module>/
# 下的源码文件，保留并更新本地原有的 <Pod>.podspec。
#
# 返回:
#   0 实际同步成功
#   1 失败
#   2 主动跳过 (xcframework / 无本地目录 / 解析不到 url 等)
sync_pod_source() {
  local pod="$1"
  local podspec="${PODSPEC_DIR}/${pod}.podspec"

  if [[ "$SYNC_SOURCE" != "1" ]]; then
    log_dim "  (SYNC_SOURCE=0, 跳过源码同步)"
    return 2
  fi

  if [[ ! -f "$podspec" ]]; then
    log_warn "$pod 同步源码: 找不到 podspec ($podspec)，已跳过"
    return 2
  fi

  local source_url version module
  source_url=$(podspec_source_url "$podspec")
  version=$(podspec_field "$podspec" "version")
  module=$(podspec_module_name "$podspec")

  if [[ -z "$source_url" ]]; then
    log_warn "$pod 同步源码: 未解析到 http 源地址，已跳过"
    return 2
  fi
  if [[ -z "$module" ]]; then
    log_warn "$pod 同步源码: 未解析到 module_name，已跳过"
    return 2
  fi

  # xcframework 二进制包不参与源码同步
  if [[ "$source_url" == *.xcframework.zip* ]]; then
    log_dim "  ($pod 是 xcframework 二进制包，无需同步源码)"
    return 2
  fi

  local target_dir="${TUIKIT_DIR}/${module}"
  if [[ ! -d "$target_dir" ]]; then
    log_warn "$pod 同步源码: 本地无对应目录 ($target_dir)，已跳过"
    return 2
  fi

  log_step "Sync source: $pod (v$version) -> ${target_dir#$REPO_ROOT/}"

  local work_dir zip_file extract_dir source_dir backup_podspec target_podspec
  target_podspec="${target_dir}/${pod}.podspec"
  work_dir=$(mktemp -d -t "tuikit-sync-${pod}.XXXXXX") || {
    log_err "$pod 同步源码: 创建临时目录失败"
    return 1
  }
  # 把 work_dir 设到一个全局变量，配合 RETURN trap 做无副作用清理
  _CURRENT_SYNC_WORKDIR="$work_dir"
  trap '[[ -n "${_CURRENT_SYNC_WORKDIR:-}" ]] && rm -rf "$_CURRENT_SYNC_WORKDIR"; _CURRENT_SYNC_WORKDIR=""; trap - RETURN' RETURN

  zip_file="${work_dir}/${pod}.zip"
  extract_dir="${work_dir}/extract"
  mkdir -p "$extract_dir"

  log_dim "  downloading: $source_url"
  if ! curl -sSL --fail --max-time "$DOWNLOAD_TIMEOUT" -o "$zip_file" "$source_url"; then
    log_err "$pod 同步源码: 下载失败 ($source_url)"
    return 1
  fi
  log_dim "  zip size   : $(du -h "$zip_file" 2>/dev/null | awk '{print $1}')"

  if ! unzip -qq -o "$zip_file" -d "$extract_dir" 2>"${work_dir}/unzip.err"; then
    log_err "$pod 同步源码: 解压失败"
    cat "${work_dir}/unzip.err" 2>/dev/null
    return 1
  fi

  # 优先匹配与 module 同名的顶层目录；找不到则取除 __MACOSX 外的第一个顶层目录
  source_dir="${extract_dir}/${module}"
  if [[ ! -d "$source_dir" ]]; then
    source_dir=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d \
      ! -name "__MACOSX" 2>/dev/null | head -1)
  fi
  if [[ -z "$source_dir" || ! -d "$source_dir" ]]; then
    log_err "$pod 同步源码: 解压目录中找不到源码"
    return 1
  fi

  # 备份本地 podspec
  if [[ -f "$target_podspec" ]]; then
    backup_podspec="${work_dir}/${pod}.podspec.bak"
    cp "$target_podspec" "$backup_podspec"
  else
    backup_podspec=""
    log_warn "$pod 同步源码: 本地无 $pod.podspec，将不还原 (新建模块?)"
  fi

  # 清空目标目录 (保留目录本身)
  log_dim "  clearing   : ${target_dir#$REPO_ROOT/}/"
  if ! ( cd "$target_dir" && find . -mindepth 1 -delete ); then
    log_err "$pod 同步源码: 清空 $target_dir 失败"
    return 1
  fi

  # 拷贝解压后的源码 (用 tar 管道保证隐藏文件 / 权限)
  log_dim "  copying    : $(basename "$source_dir")/ -> ${target_dir#$REPO_ROOT/}/"
  if ! ( cd "$source_dir" && tar cf - . ) | ( cd "$target_dir" && tar xf - ); then
    log_err "$pod 同步源码: 拷贝源码失败"
    return 1
  fi

  # 还原本地 podspec 并把版本号同步到刚发布的版本
  if [[ -n "$backup_podspec" ]]; then
    cp "$backup_podspec" "$target_podspec"
    if bump_podspec_version "$target_podspec" "$version"; then
      log_ok "$pod 源码已同步 (保留 $pod.podspec，版本号 -> $version)"
    else
      log_warn "$pod 源码已同步，但更新 podspec 版本号失败"
    fi
  else
    log_ok "$pod 源码已同步"
  fi

  return 0
}

# 验证 pod 是否真的发布出去了 (因为 5xx 误判)
verify_pod() {
  local pod="$1"
  local json="/tmp/${pod}.podspec.json"
  local target_ver
  target_ver=$(grep -m1 '"version"' "$json" 2>/dev/null | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/')
  if [[ -z "$target_ver" ]]; then
    target_ver=$(awk -F"'" '/spec\.version/{print $2; exit}' "${PODSPEC_DIR}/${pod}.podspec")
  fi

  local latest
  latest=$(pod trunk info "$pod" 2>/dev/null | awk '/^[[:space:]]+- [0-9]/' | tail -1 | sed 's/^[[:space:]]*//')

  if echo "$latest" | grep -q "$target_ver"; then
    log_ok "$pod -> $latest"
    return 0
  else
    log_err "$pod -> $latest (期望 $target_ver)"
    return 1
  fi
}

# ---- Podfile 更新 / 编译验证 ----------------------------------------------

# 把 Podfile 里某个 pod 的版本号 pin 改成新版本:
#   pod 'Name', 'x.y.z'   ->   pod 'Name', '<new>'
# 只匹配带固定版本号的行; 带 :path/:git 或无版本的行不动。
# 返回: 0 已更新 / 1 无匹配(或版本一致, 无需改)
update_podfile_pod() {
  local podfile="$1" name="$2" new_version="$3"
  [[ -f "$podfile" && -n "$new_version" ]] || return 1

  # 转义 pod 名里的正则元字符 (pod 名通常只有字母数字下划线, 稳妥起见)
  local name_re
  name_re=$(printf '%s' "$name" | sed -E 's/[][(){}.^$*+?|\\]/\\&/g')

  # 当前是否已是该版本
  local cur
  cur=$(grep -m1 -E "^[[:space:]]*pod[[:space:]]+['\"]${name_re}['\"][[:space:]]*,[[:space:]]*['\"][^'\"]+['\"]" "$podfile" \
        | sed -E "s/.*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")
  [[ -z "$cur" ]] && return 1
  [[ "$cur" == "$new_version" ]] && return 1

  _sed_inplace \
    "s/(pod[[:space:]]+['\"]${name_re}['\"][[:space:]]*,[[:space:]]*['\"])[^'\"]+(['\"])/\1${new_version}\2/g" \
    "$podfile"
  return 0
}

# 发布完成后, 把 Podfile 里所有"本次目标 pod"的版本更新到其 podspec 版本。
# 入参: 目标 pod 列表
# 通过全局数组返回结果: PODFILE_UPDATED / PODFILE_UNCHANGED
update_podfile_versions() {
  PODFILE_UPDATED=()
  PODFILE_UNCHANGED=()
  local pod spec ver
  for pod in "$@"; do
    spec="${PODSPEC_DIR}/${pod}.podspec"
    [[ -f "$spec" ]] || continue
    ver=$(podspec_field "$spec" "version")
    [[ -z "$ver" ]] && continue
    if update_podfile_pod "$PODFILE" "$pod" "$ver"; then
      PODFILE_UPDATED+=("${pod}->${ver}")
      log_ok "Podfile: ${pod} -> ${ver}"
    else
      PODFILE_UNCHANGED+=("$pod")
    fi
  done
}

# 在 TUIKitDemo 目录跑 pod install
# 返回: 0 成功 / 1 失败
run_demo_pod_install() {
  if [[ ! -f "$PODFILE" ]]; then
    log_warn "pod install: 找不到 Podfile ($PODFILE)，已跳过"
    return 1
  fi
  log_step "pod install (${DEMO_DIR#$REPO_ROOT/})"
  if ( cd "$DEMO_DIR" && pod install --repo-update ); then
    log_ok "pod install 完成"
    return 0
  fi
  log_err "pod install 失败"
  return 1
}

# 编译验证 TUIKitDemo (iOS 模拟器, 免签名)
# 返回: 0 BUILD SUCCEEDED / 1 失败
verify_demo_build() {
  if [[ ! -d "${DEMO_DIR}/${DEMO_WORKSPACE}" ]]; then
    log_warn "编译验证: 找不到 workspace (${DEMO_WORKSPACE})，已跳过"
    return 1
  fi
  if ! command -v xcodebuild >/dev/null 2>&1; then
    log_warn "编译验证: 未找到 xcodebuild，已跳过"
    return 1
  fi
  log_step "编译验证 TUIKitDemo (scheme=${DEMO_SCHEME}, dest=${DEMO_DESTINATION})"
  local log="/tmp/tuikitdemo_build.log"
  if ( cd "$DEMO_DIR" && xcodebuild \
        -workspace "$DEMO_WORKSPACE" \
        -scheme "$DEMO_SCHEME" \
        -configuration Debug \
        -sdk iphonesimulator \
        -destination "$DEMO_DESTINATION" \
        CODE_SIGNING_ALLOWED=NO \
        build ) >"$log" 2>&1; then
    log_ok "TUIKitDemo 编译通过 (BUILD SUCCEEDED)"
    return 0
  fi
  log_err "TUIKitDemo 编译失败, 末尾日志如下 (完整: $log):"
  grep -E "error:|BUILD FAILED" "$log" | tail -30
  return 1
}

# ---- 主流程 --------------------------------------------------------------
main() {
  # 解析参数: -v/--version <x.y.z> 用于在发布前统一更新版本号, 其余为 pod 名
  local set_version=""
  local positional=()
  while (( $# > 0 )); do
    case "$1" in
      -v|--version)
        set_version="${2:-}"; shift 2 ;;
      --version=*)
        set_version="${1#*=}"; shift ;;
      --update-podfile)
        UPDATE_PODFILE=1; shift ;;
      --verify-build)
        VERIFY_BUILD=1; shift ;;
      --no-pod-install)
        RUN_POD_INSTALL=0; shift ;;
      *)
        positional+=("$1"); shift ;;
    esac
  done
  # 也允许用环境变量 SET_VERSION 传入
  set_version="${set_version:-${SET_VERSION:-}}"

  if [[ -n "$set_version" ]]; then
    if [[ ! "$set_version" =~ ^[0-9]+(\.[0-9]+)+([A-Za-z0-9]+)?$ ]]; then
      log_err "版本号格式不合法: '$set_version' (期望形如 8.9.7600)"
      return 1
    fi
  fi

  log_step "Podspec dir: $PODSPEC_DIR"

  local pods=()
  if (( ${#positional[@]} > 0 )); then
    pods=("${positional[@]}")
  else
    pods=("${DEFAULT_PODS[@]}")
  fi

  # 若指定了版本号: 先把这些 pod 的 podspec 三处版本号统一更新
  if [[ -n "$set_version" ]]; then
    log_step "更新版本号 -> ${set_version} (${#pods[@]} 个 podspec)"
    local vp old_v
    for vp in "${pods[@]}"; do
      local vp_spec="${PODSPEC_DIR}/${vp}.podspec"
      if [[ ! -f "$vp_spec" ]]; then
        log_warn "${vp}: 找不到 podspec，跳过版本更新"
        continue
      fi
      old_v=$(podspec_field "$vp_spec" "version")
      if bump_podspec_all "$vp_spec" "$set_version"; then
        if [[ "$old_v" == "$set_version" ]]; then
          log_dim "  ${vp}: 已是 ${set_version}"
        else
          log_ok "${vp}: ${old_v} -> ${set_version} (version + source URL + 依赖约束)"
        fi
      else
        log_err "${vp}: 版本更新失败"
      fi
    done
  fi

  local TOKEN
  TOKEN=$(get_trunk_token)

  log_step "待发布 (${#pods[@]} 个): ${pods[*]}"

  local push_failed=()
  local push_skipped=()
  local bumped=()
  local bump_failed=()
  local synced=()
  local sync_failed=()
  local sync_skipped=()
  local push_rc
  for pod in "${pods[@]}"; do
    if [[ "$SKIP_PUBLISH" == "1" ]]; then
      log_step "Skip push: $pod (SKIP_PUBLISH=1)"
      push_rc=0
    else
      push_pod "$pod" "$TOKEN"
      push_rc=$?
      case "$push_rc" in
        0) ;;                              # success
        2) push_skipped+=("$pod") ;;       # 版本号不匹配，主动跳过
        *) push_failed+=("$pod") ;;
      esac
    fi

    if (( push_rc == 0 )); then
      # 1) 推送成功 -> 始终回写本地 podspec 版本号 (无论是否同步源码)
      bump_local_podspec "$pod"
      case "$?" in
        0) bumped+=("$pod") ;;
        2) ;;                              # 本地无 podspec，正常跳过
        *) bump_failed+=("$pod") ;;
      esac

      # 2) 同步源码 (sync_pod_source 内部会再次写一次版本，保证 restore 后一致)
      if [[ "$SYNC_SOURCE" == "1" ]]; then
        sync_pod_source "$pod"
        case "$?" in
          0) synced+=("$pod") ;;
          2) sync_skipped+=("$pod") ;;
          *) sync_failed+=("$pod") ;;
        esac
      fi
    else
      sync_skipped+=("$pod")
    fi
  done

  local verify_failed=()
  if [[ "$SKIP_PUBLISH" != "1" ]]; then
    log_step "校验 Trunk 上的实际版本"
    for pod in "${pods[@]}"; do
      if ! verify_pod "$pod"; then
        verify_failed+=("$pod")
      fi
    done
  fi

  # ---- 发布后: 更新 Podfile + (可选) pod install + (可选) 编译验证 ----
  PODFILE_UPDATED=(); PODFILE_UNCHANGED=()
  local pod_install_done="-" build_result="-"
  if [[ "$UPDATE_PODFILE" == "1" || "$VERIFY_BUILD" == "1" ]]; then
    if [[ "$UPDATE_PODFILE" == "1" ]]; then
      log_step "更新 Podfile 依赖版本 -> 本次发布版本"
      update_podfile_versions "${pods[@]}"
      (( ${#PODFILE_UPDATED[@]} == 0 )) && log_dim "  (Podfile 无需更新, 版本已是最新)"
    fi
    # 需要 pod install 的场景: 显式 VERIFY_BUILD, 或 UPDATE_PODFILE 且开启了 RUN_POD_INSTALL
    if [[ "$VERIFY_BUILD" == "1" ]] \
      || { [[ "$UPDATE_PODFILE" == "1" && "$RUN_POD_INSTALL" == "1" ]]; }; then
      if run_demo_pod_install; then pod_install_done="ok"; else pod_install_done="failed"; fi
    fi
    if [[ "$VERIFY_BUILD" == "1" ]]; then
      if [[ "$pod_install_done" == "failed" ]]; then
        log_warn "pod install 失败, 跳过编译验证"
        build_result="skipped"
      elif verify_demo_build; then
        build_result="passed"
      else
        build_result="failed"
      fi
    fi
  fi

  echo ""
  log_step "总结"
  if [[ "$SKIP_PUBLISH" != "1" ]]; then
    echo "  发布尝试失败  : ${#push_failed[@]} 个  ${push_failed[*]:-}"
    if (( ${#push_skipped[@]} > 0 )); then
      echo "  版本不匹配跳过: ${#push_skipped[@]} 个  ${push_skipped[*]}"
    fi
    echo "  最终校验失败  : ${#verify_failed[@]} 个  ${verify_failed[*]:-}"
  fi
  echo "  本地版本回写  : ${#bumped[@]} 个  ${bumped[*]:-}"
  if (( ${#bump_failed[@]} > 0 )); then
    echo "  本地版本回写失败: ${#bump_failed[@]} 个  ${bump_failed[*]}"
  fi
  if [[ "$SYNC_SOURCE" == "1" ]]; then
    echo "  源码同步成功  : ${#synced[@]} 个  ${synced[*]:-}"
    echo "  源码同步失败  : ${#sync_failed[@]} 个  ${sync_failed[*]:-}"
    if (( ${#sync_skipped[@]} > 0 )); then
      echo "  源码同步跳过  : ${#sync_skipped[@]} 个  ${sync_skipped[*]}"
    fi
  fi
  if [[ "$UPDATE_PODFILE" == "1" ]]; then
    echo "  Podfile 更新  : ${#PODFILE_UPDATED[@]} 个  ${PODFILE_UPDATED[*]:-}"
  fi
  if [[ "$pod_install_done" != "-" ]]; then
    echo "  pod install   : ${pod_install_done}"
  fi
  if [[ "$VERIFY_BUILD" == "1" ]]; then
    echo "  编译验证      : ${build_result}"
  fi

  if (( ${#push_failed[@]} > 0 )) \
    || (( ${#verify_failed[@]} > 0 )) \
    || (( ${#sync_failed[@]} > 0 )) \
    || (( ${#bump_failed[@]} > 0 )) \
    || [[ "$pod_install_done" == "failed" ]] \
    || [[ "$build_result" == "failed" ]]; then
    return 1
  fi
  return 0
}

main "$@"
