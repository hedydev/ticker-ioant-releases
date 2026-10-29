# ticker-ioant-releases
Official downloads and release notes for Ticker ioant

## macOS ClashX Meta / IOANT REALITY temporary bootstrap

A macOS installer with automatic IOANT VLESS + REALITY + Vision configuration is published at:

`scripts/install_clashx_meta_reality.sh`

No GitHub account, GitHub CLI, SSH PEM, or manual VLESS URI entry is required by the receiving Mac. Download from the public **pinned** revision and inspect/test locally before execution:

```bash
bash <<'BASH'
set -euo pipefail
SCRIPT="$HOME/Downloads/install_clashx_meta_reality.sh"
mkdir -p "$HOME/Downloads"
curl -fLsS --retry 3 --proto '=https' --tlsv1.2 \
  "https://raw.githubusercontent.com/hedydev/ticker-ioant-releases/fbf25780aee44eb23cec7dd03a70d55f6f0cdcfb/scripts/install_clashx_meta_reality.sh" \
  -o "$SCRIPT"
bash -n "$SCRIPT"
bash "$SCRIPT" --self-test
bash "$SCRIPT"
BASH
```

**Security notice:** This is a temporary, explicitly owner-authorized public distribution that embeds a usable VLESS client access credential. Anyone who downloads it can recover that credential. It is **not** an AWS SSH PEM. Publishing a replacement and deleting this file will not revoke previously obtained access: rotate the server-side client UUID after the installation window. Leave normal website/OTA DNS and the REALITY port unchanged. The installer will not overwrite an existing same-named profile or change system proxy automatically; users must enable it from the ClashX Meta menu.

Source version: `hedydev/ioant-v2proxyshell@e89b94408ae16e3c339a9dbf920a47ccd3fda8f7`.
