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

## Reliable 4-way ClashX Meta download from WFK Lightsail

For Macs with unstable large GitHub Release downloads, a **public, credential-free** downloader is available:

```bash
bash <<'BASH'
set -euo pipefail
SCRIPT="$HOME/Downloads/download_clashx_meta_lightsail.py"
mkdir -p "$HOME/Downloads"
curl -fLsS --retry 3 --connect-timeout 10 --max-time 45 \
  'https://raw.githubusercontent.com/hedydev/ticker-ioant-releases/18f059845a2bf7568eeb309fce5b4d4c199709bf/scripts/download_clashx_meta_lightsail.py' \
  -o "$SCRIPT"
python3 "$SCRIPT" --self-test
python3 "$SCRIPT" download
BASH
```

It downloads 86 verified HTTP Range chunks over 4 concurrent strict-TLS connections to `https://ioant.com:18443/ClashX.Meta.zip` (fixed IP `13.213.140.184`) and retains completed parts across retries. It checks HTTP 206, Content-Range, exact total length `89683343`, upstream SHA-256 `cc76aa2e561df8e127147324c60a787522001aa0f71ebe9b394ea8e23d809e40` and ZIP integrity. It leaves `~/Downloads/ClashX.Meta-Lightsail.zip`. It does **not** install apps or configure/enable the system proxy. The separately published `install_clashx_meta_reality.sh` configures the IOANT node after the verified app is installed.

Availability of the WFK 18443 endpoint depends on the owner's temporary service and firewall being kept enabled. The downloader itself contains no VLESS URI or SSH keys.
