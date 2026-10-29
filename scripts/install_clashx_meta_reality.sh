#!/bin/bash
# TEMPORARY PUBLIC INSTALLER: contains a live VLESS client credential.
# Publication explicitly authorized by the credential owner.
# Rotate the server-side UUID after the public distribution window.
# Origin: hedydev/ioant-v2proxyshell @ e89b94408ae16e3c339a9dbf920a47ccd3fda8f7
set -euo pipefail
umask 077

APP_VERSION="v1.4.47"
APP_ZIP_SHA256="cc76aa2e561df8e127147324c60a787522001aa0f71ebe9b394ea8e23d809e40"
APP_ZIP_URL="https://github.com/MetaCubeX/ClashX.Meta/releases/download/${APP_VERSION}/ClashX.Meta.zip"
SERVER="13.213.140.184"
PORT="28443"
# Temporary auto-import: contains a live access credential. Rotate after testing.
AUTO_URI="vless://75bdb4b5-e423-44a6-b8f7-a825d9981798@13.213.140.184:28443?encryption=none&security=reality&type=tcp&sni=www.bing.com&fp=chrome&pbk=jIKGG2lR3EEyas0BBbTpQslqYxYIuPUhE6lTPmSznxE&sid=1c52abaa5fe23667&flow=xtls-rprx-vision#IOANT-Lightsail-REALITY"
PROFILE_NAME="IOANT-Lightsail-REALITY-28443.yaml"
CONFIG_DIR="$HOME/.config/clash.meta"
PROFILE_PATH="$CONFIG_DIR/$PROFILE_NAME"
DEFAULT_PATH="$CONFIG_DIR/config.yaml"
CONFIG_FILE=""
MODE="install"
TMP_DIR=""

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
cleanup() { if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then rm -rf "$TMP_DIR"; fi; }
trap cleanup EXIT

usage() {
  cat <<'HELP'
Usage:
  bash install_clashx_meta_reality.sh
  bash install_clashx_meta_reality.sh --config-file /path/to/working-profile.yaml
  bash install_clashx_meta_reality.sh --self-test

This script installs ClashX Meta on macOS, then auto-imports the embedded
IOANT Lightsail VLESS+REALITY node without manual URI entry.
WARNING: This temporary installer contains an access credential in its source.
Do not keep it public; rotate the node UUID after testing.
It refuses to overwrite existing configurations, does not automatically
change system proxy, and does not modify your AWS server.
HELP
}

parse_vless_uri() {
  local uri="$1" authority query pair key value
  URI_UUID=""; URI_PBK=""; URI_SID=""; URI_SNI=""; URI_FP=""; URI_FLOW=""
  local encryption="" security="" transport="" hostport=""
  local -a pairs=()
  [[ "$uri" == vless://* ]] || return 1
  uri="${uri#vless://}"
  uri="${uri%%#*}"
  [[ "$uri" == *\?* ]] || return 1
  authority="${uri%%\?*}"
  query="${uri#*\?}"
  [[ "$authority" == *@* ]] || return 1
  URI_UUID="${authority%@*}"
  hostport="${authority#*@}"
  [[ "$hostport" == "${SERVER}:${PORT}" ]] || return 1
  [[ "$URI_UUID" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || return 1
  IFS='&' read -r -a pairs <<< "$query"
  for pair in "${pairs[@]}"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    [[ "$pair" == *=* ]] || return 1
    case "$key" in
      encryption) encryption="$value" ;;
      security) security="$value" ;;
      type) transport="$value" ;;
      sni) URI_SNI="$value" ;;
      fp) URI_FP="$value" ;;
      pbk) URI_PBK="$value" ;;
      sid) URI_SID="$value" ;;
      flow) URI_FLOW="$value" ;;
      *) return 1 ;;
    esac
  done
  [[ "$encryption" == none && "$security" == reality && "$transport" == tcp ]] || return 1
  [[ "$URI_FLOW" == xtls-rprx-vision ]] || return 1
  [[ "$URI_FP" == chrome ]] || return 1
  [[ "$URI_SNI" =~ ^[A-Za-z0-9.-]{1,120}$ ]] || return 1
  [[ "$URI_PBK" =~ ^[A-Za-z0-9_-]{20,128}$ ]] || return 1
  [[ "$URI_SID" =~ ^[[:xdigit:]]{0,32}$ ]] || return 1
  return 0
}

write_profile() {
  local output="$1"
  cat > "$output" <<YAML
# IOANT personal VLESS+REALITY configuration. KEEP PRIVATE.
# Created locally; not uploaded to GitHub or the installation server.
mixed-port: 7897
allow-lan: false
mode: rule
log-level: warning
ipv6: false
proxies:
  - name: IOANT-Lightsail-REALITY
    type: vless
    server: ${SERVER}
    port: ${PORT}
    uuid: "${URI_UUID}"
    network: tcp
    tls: true
    udp: true
    servername: "${URI_SNI}"
    client-fingerprint: "${URI_FP}"
    reality-opts:
      public-key: "${URI_PBK}"
      short-id: "${URI_SID}"
    flow: "${URI_FLOW}"
proxy-groups:
  - name: IOANT-PROXY
    type: select
    proxies:
      - IOANT-Lightsail-REALITY
      - DIRECT
rules:
  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
  - GEOIP,CN,DIRECT
  - MATCH,IOANT-PROXY
YAML
}

self_test() {
  local fake_uri fixture
  fixture="$(mktemp)"
  fake_uri='vless://123e4567-e89b-12d3-a456-426614174000@13.213.140.184:28443?encryption=none&security=reality&type=tcp&sni=www.bing.com&fp=chrome&pbk=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq&sid=01234567&flow=xtls-rprx-vision#test'
  parse_vless_uri "$fake_uri" || die 'self-test: valid URI rejected'
  write_profile "$fixture"
  grep -q 'server: 13.213.140.184' "$fixture" || die 'self-test: server missing'
  grep -q 'flow: "xtls-rprx-vision"' "$fixture" || die 'self-test: flow missing'
  if parse_vless_uri "${fake_uri/28443/443}"; then die 'self-test: wrong port accepted'; fi
  if parse_vless_uri "${fake_uri/xtls-rprx-vision/none}"; then die 'self-test: wrong flow accepted'; fi
  parse_vless_uri "$AUTO_URI" || die 'self-test: embedded URI rejected'
  write_profile "$fixture"
  grep -q '    type: vless' "$fixture" || die 'self-test: auto profile missing VLESS'
  grep -q '    tls: true' "$fixture" || die 'self-test: auto profile missing TLS'
  rm -f "$fixture"
  say 'IOANT_CLASHX_META_BOOTSTRAP_SELF_TEST_PASS'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config-file)
      [ "$#" -ge 2 ] || die '--config-file requires a path'
      CONFIG_FILE="$2"; shift 2 ;;
    --self-test) MODE="self-test"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die 'unknown option (see --help)' ;;
  esac
done

if [ "$MODE" = 'self-test' ]; then self_test; exit 0; fi
[ "$(uname -s)" = Darwin ] || die 'only macOS is supported'
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[[ "$MAJOR" =~ ^[0-9]+$ ]] || die 'cannot detect macOS version'
[ "$MAJOR" -ge 13 ] || die 'ClashX Meta requires macOS 13 or newer'
for tool in curl ditto unzip codesign open mktemp shasum awk; do command -v "$tool" >/dev/null || die "missing command: $tool"; done

if [ -n "$CONFIG_FILE" ]; then
  [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ] || die 'supplied config file is not readable'
  grep -qi 'type:[[:space:]]*vless' "$CONFIG_FILE" || die 'supplied file has no VLESS proxy'
  grep -q '13\.213\.140\.184' "$CONFIG_FILE" || die 'supplied file does not target WFK Lightsail'
  grep -q '28443' "$CONFIG_FILE" || die 'supplied file does not target port 28443'
  grep -q 'reality-opts:' "$CONFIG_FILE" || die 'supplied file does not contain Reality parameters'
else
  parse_vless_uri "$AUTO_URI" || die 'embedded VLESS URI invalid or does not match IOANT Lightsail REALITY TCP 28443'
  say '已校验预置 IOANT-Lightsail-REALITY 节点，无需粘贴 URI。'
fi

APP_PATH=""
for candidate in \
  '/Applications/ClashX Meta.app' '/Applications/ClashX.Meta.app' \
  "$HOME/Applications/ClashX Meta.app" "$HOME/Applications/ClashX.Meta.app"; do
  if [ -d "$candidate" ]; then APP_PATH="$candidate"; break; fi
done
if [ -n "$APP_PATH" ]; then
  say 'ClashX Meta 已安装；不会覆盖现有应用。'
else
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp/}ioant-clashx-meta.XXXXXXXX")"
  ZIP="$TMP_DIR/ClashX.Meta.zip"
  EXPANDED="$TMP_DIR/unpacked"
  mkdir -p "$EXPANDED"
  say "从发布者 GitHub 下载 ClashX Meta ${APP_VERSION} …"
  curl --fail --location --silent --show-error --retry 3 \
    --connect-timeout 20 --proto '=https' --tlsv1.2 \
    "$APP_ZIP_URL" --output "$ZIP" || die 'ClashX Meta download failed'
  ACTUAL_SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
  [ "$ACTUAL_SHA256" = "$APP_ZIP_SHA256" ] || die 'ClashX Meta release SHA-256 mismatch; installation aborted'
  unset ACTUAL_SHA256
  unzip -tqq "$ZIP" || die 'downloaded ZIP verification failed'
  ditto -x -k "$ZIP" "$EXPANDED"
  BUNDLE="$(find "$EXPANDED" -maxdepth 4 -type d -name '*.app' -prune -print -quit)"
  [ -n "$BUNDLE" ] || die 'application bundle not found in ZIP'
  case "$(basename "$BUNDLE")" in *ClashX*.app) ;; *) die 'unexpected application bundle';; esac
  /usr/bin/codesign --verify --deep --strict "$BUNDLE" 2>/dev/null || die 'application code signature validation failed; install aborted'
  if [ -w /Applications ]; then APPS_DIR=/Applications; else APPS_DIR="$HOME/Applications"; fi
  mkdir -p "$APPS_DIR"
  APP_PATH="$APPS_DIR/$(basename "$BUNDLE")"
  [ ! -e "$APP_PATH" ] || die 'destination app appeared concurrently; manual review required'
  ditto "$BUNDLE" "$APP_PATH"
  say "已安装到：$APP_PATH"
fi

mkdir -p "$CONFIG_DIR"
if [ -e "$PROFILE_PATH" ]; then
  die 'existing IOANT profile detected; refusing to overwrite. Compare and rename it manually if needed'
fi
STAGING="$(mktemp "$CONFIG_DIR/.ioant-profile.XXXXXXXX")"
if [ -n "$CONFIG_FILE" ]; then
  cat "$CONFIG_FILE" > "$STAGING"
else
  write_profile "$STAGING"
  URI_UUID=""; URI_PBK=""; URI_SID=""; URI_SNI=""; URI_FP=""; URI_FLOW=""
fi
chmod 600 "$STAGING"
mv -n "$STAGING" "$PROFILE_PATH"
[ -s "$PROFILE_PATH" ] || die 'profile not written'
if [ ! -e "$DEFAULT_PATH" ]; then
  cp -p "$PROFILE_PATH" "$DEFAULT_PATH"
  chmod 600 "$DEFAULT_PATH"
  say '首次安装：已建立默认 config.yaml。'
else
  say '检测到现有 config.yaml：保持不动，请在 ClashX Meta 菜单 Config 中切换到 IOANT 配置。'
fi
say "已写入私有配置：$PROFILE_PATH"
/usr/bin/open "$APP_PATH" || die 'application installed but launch failed; open it manually'
cat <<'NEXT'
完成：应用和 IOANT-Lightsail-REALITY 配置已安装。
接下来在 macOS 菜单栏 ClashX Meta 中：
  1. Config/配置 → 选择 IOANT-Lightsail-REALITY-28443（如需手动切换）
  2. 代理/Proxy 选择 IOANT-Lightsail-REALITY
  3. 点击 Set as System Proxy（设为系统代理）
  4. 如果 macOS 提示授权，请按系统提示批准。
提示：此脚本不会接管现有代理或删除旧配置，也不会修改 AWS 服务器。
NEXT
