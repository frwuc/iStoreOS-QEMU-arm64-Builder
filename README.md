# iStoreOS QEMU ARM64 Builder

基于 GitHub Actions 的 iStoreOS QEMU ARM64 虚拟机固件自动构建工作流。

## 用法

1. **Fork 本项目**
2. 进入 Actions 页面，选择 **Build iStoreOS 24.10.x QEMU-armsr-armv8**
3. 点击 **Run workflow**，按需配置参数：
   - **istoreos_version** — iStoreOS 版本（默认 24.10.7）
   - **rootfs_partsize** — 固件大小，单位 MB（默认 2048，最大 10240）
   - **enable_store** — 是否集成 iStore 商店（默认启用）
   - **enable_pppoe** — 是否配置 PPPoE 拨号（默认否）

4. 构建完成后，发布页面会提供 `.qcow2` / `.vmdk` 格式的固件下载

## 输出

- QCOW2 镜像 — 适用于 PVE、QEMU、UTM 等 ARM64 虚拟机
- VMDK 镜像 — 适用于 VMware、VirtualBox 等

## 注意事项

- 固件基于 iStoreOS 官方 ImageBuilder 打包，默认自带 luci-app-store
- 默认管理地址：单网口 DHCP 自动获取 IP；多网口 LAN 口 IP 为 `192.168.100.1`
- 默认 Rootfs 大小 2048 MB，可在工作流参数中调整

## 致谢

本项目修改自 [wukongdaily/ImmortalWrt-ImageBuilder](https://github.com/wukongdaily/ImmortalWrt-ImageBuilder)，在其基础上适配了 iStoreOS ImageBuilder 构建流程。
