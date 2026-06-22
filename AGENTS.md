# AGENTS.md — iStoreOS QEMU ARM64 Builder

## Project overview

CI-only build project. No local dev setup, no tests, no linter. Builds iStoreOS (OpenWrt-based) ARM64 VM firmware via GitHub Actions using iStoreOS ImageBuilder.

## Key files

| File | Purpose |
|------|---------|
| `.github/workflows/build-iStoreOS-arm64-24.10.x.yml` | CI entrypoint; triggered via `workflow_dispatch` |
| `armsr-armv8/build-istoreos.sh` | Main build script, runs inside CI |
| `armsr-armv8/istoreos.config` | Output format flags (qcow2, vmdk, gzip) |
| `shell/custom-packages.sh` | Optional luci packages (all commented out by default) |
| `files/etc/uci-defaults/99-custom.sh` | First-boot script: auto-detects LAN IP from WAN DHCP gateway |
| `armsr-armv8/istoreos-info.md` | GitHub Release body text |

## Build flow

1. CI downloads iStoreOS ImageBuilder tarball from `fw.koolcenter.com`
2. Appends `istoreos.config` to ImageBuilder's `.config`
3. Copies `files/` directory into ImageBuilder's `files/`
4. Runs `make image PROFILE=generic PACKAGES="..." FILES="files" ROOTFS_PARTSIZE=N`
5. Output lands in `imagebuilder/bin/targets/armsr/armv8/`

## Output formats

- `istoreos.config` sets `CONFIG_QCOW2_IMAGES=y` and `CONFIG_VMDK_IMAGES=y`
- If ImageBuilder doesn't produce qcow2 natively, CI converts vmdk → qcow2 via `qemu-img convert`
- Both `.qcow2` and `.vmdk` are uploaded as GitHub Release assets

## Workflow inputs (workflow_dispatch)

- `istoreos_version` — ImageBuilder version tag (24.10.x)
- `rootfs_partsize` — rootfs size in MB (default 2048, max 10240)
- `lan_ipaddr` — LAN IP (empty = auto-detect from WAN DHCP gateway)
- `enable_pppoe` + `pppoe_account` + `pppoe_password` — PPPoE config
- `enable_store` — boolean, default true (iStoreOS already ships luci-app-store)

## Gotchas

- **Must disable Secure Boot** when creating VM: `--boot uefi,firmware.feature.name=secure-boot,firmware.feature.enabled=no`
- Default branch: `istoreos24.10.x-qemu-armv8`
- First-boot LAN IP auto-detection: reads `LAN_IPADDR` from `/etc/config/lan-settings` (set at build time), falls back to inferring from WAN DHCP gateway, final fallback `192.168.100.1`
- PPPoE credentials written to `/etc/config/pppoe-settings` at build time, consumed by `99-custom.sh`
- OpenClash/mihomo cores downloaded at build time if respective luci apps are selected in `custom-packages.sh`
