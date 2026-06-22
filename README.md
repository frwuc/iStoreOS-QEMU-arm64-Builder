# iStoreOS QEMU ARM64 Builder

基于 GitHub Actions 的 iStoreOS QEMU ARM64 虚拟机固件自动构建工作流。

## 用法

1. **Fork 本项目**
2. 进入 Actions 页面，选择 **Build iStoreOS 24.10.x QEMU-armsr-armv8**
3. 点击 **Run workflow**，按需配置参数：
   - **istoreos_version** — iStoreOS 版本（默认 24.10.7）
   - **rootfs_partsize** — 固件大小，单位 MB（默认 2048，最大 10240）
   - **enable_store** — 是否集成 iStore 商店（默认启用）
   - **lan_ipaddr** — LAN 口 IP 地址（留空则首次启动自动检测网关网段）
   - **enable_pppoe** — 是否配置 PPPoE 拨号（默认否）
4. 构建完成后，发布页面会提供 `.qcow2` / `.vmdk` 格式的固件下载

## 输出

| 文件 | 格式 | 适用平台 |
|------|------|----------|
| `*.qcow2` | QEMU Copy-On-Write | Armbian + KVM/QEMU, PVE, UTM |
| `*.vmdk` | VMware Virtual Disk | VMware, VirtualBox, PVE |

## 使用指南

### 一、使用本项目构建的镜像

#### 1. 安装 KVM 相关组件（Armbian）

```bash
sudo apt update
sudo apt install -y qemu-kvm virt-manager libvirt-daemon-system libvirt-clients bridge-utils
sudo systemctl enable --now libvirtd
```

#### 2. 配置网桥（可选，用于给虚拟机分配独立 IP）

```bash
sudo nmcli connection add type bridge ifname br0
sudo nmcli connection add type bridge-slave ifname eth0 master br0
sudo nmcli connection up br0
```

#### 3. 创建并启动虚拟机

> **重要：必须禁用 Secure Boot**，否则 iStoreOS 无法引导。

```bash
sudo virt-install \
  --name istoreos \
  --arch aarch64 \
  --vcpus 2 \
  --memory 1024 \
  --disk path=/path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.qcow2,format=qcow2,bus=virtio \
  --network bridge=br0,model=virtio \
  --import \
  --boot uefi,firmware.feature.name=secure-boot,firmware.feature.enabled=no \
  --os-variant linux2024 \
  --noautoconsole
```

#### 4. 访问管理界面

- 首次启动时，脚本会自动检测 WAN 口 DHCP 获取的网关网段，将 LAN 口 IP 设为 `网关网段.100`（例如网关 `192.168.8.1` 则 LAN 为 `192.168.8.100`）
- 若 DHCP 获取失败，则回退到 `192.168.100.1`
- 浏览器访问 LAN 口 IP，用户名 `root`，密码为空

#### 5. 扩展磁盘大小

```bash
sudo qemu-img resize /path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.qcow2 +4G
```

然后在 iStoreOS 内使用 `diskman` 或 `parted` 扩展分区。

---

### 二、直接使用官方 iStoreOS 镜像

如果你不想自行构建，可以直接下载 iStoreOS 官方提供的 ARM64 镜像并转换为 qcow2 使用。

#### 1. 下载官方镜像

```bash
wget https://fw0.koolcenter.com/iStoreOS/armsr/istoreos-24.10.7-2026060510-armsr-squashfs-combined-efi.img.gz
gunzip istoreos-24.10.7-2026060510-armsr-squashfs-combined-efi.img.gz
```

#### 2. 转换为 qcow2

```bash
qemu-img convert -f raw -O qcow2 istoreos-24.10.7-2026060510-armsr-squashfs-combined-efi.img istoreos-official.qcow2
```

#### 3. 创建虚拟机

```bash
sudo virt-install \
  --name istoreos \
  --arch aarch64 \
  --vcpus 2 \
  --memory 1024 \
  --disk path=istoreos-official.qcow2,format=qcow2,bus=virtio \
  --network bridge=br0,model=virtio \
  --import \
  --boot uefi,firmware.feature.name=secure-boot,firmware.feature.enabled=no \
  --os-variant linux2024 \
  --noautoconsole
```

#### 4. 访问管理界面

官方镜像默认 LAN 为 `192.168.100.1`，浏览器访问 `http://192.168.100.1`，用户名 `root`，密码为空。

---

### 三、vmdk 在其他平台使用

#### VMware Workstation / Player

1. 打开 VMware，选择 **File > New Virtual Machine**
2. 选择 **Custom (Advanced)** > 下一步
3. 硬件兼容性选最新版本
4. **Guest Operating System** 选择 **Linux > Other Linux 5.x kernel 64-bit**
5. 虚拟机名称填写 `iStoreOS`
6. **处理器**：至少 1 核，推荐 2 核
7. **内存**：至少 512MB，推荐 1GB
8. **网络类型**：选择 **Bridge Networking**（桥接模式）
9. **I/O Controller**：选择 **LSI Logic**
10. **磁盘类型**：选择 **IDE**（或 SCSI）
11. **Use an existing virtual disk** > 选择下载的 `.vmdk` 文件
12. 完成创建，启动虚拟机

#### VirtualBox

```bash
VBoxManage createvm --name "iStoreOS" --ostype "Linux_ARM64" --register
VBoxManage modifyvm "iStoreOS" --memory 1024 --cpus 2
VBoxManage modifyvm "iStoreOS" --nic1 bridged --bridgeadapter1 eth0
VBoxManage storagectl "iStoreOS" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "iStoreOS" --storagectl "SATA" --port 0 --device 0 --type hdd --medium /path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.vmdk
VBoxManage startvm "iStoreOS"
```

或转换为 VDI 格式：

```bash
VBoxManage clonehd /path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.vmdk /path/to/istoreos.vdi --format VDI
```

#### PVE (Proxmox Virtual Environment)

```bash
qm create 100 --name istoreos --memory 1024 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 100 /path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.qcow2 local-lvm
qm set 100 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-100-disk-0
qm set 100 --boot order=scsi0
```

---

### 四、格式转换

```bash
# vmdk -> qcow2
qemu-img convert -f vmdk -O qcow2 input.vmdk output.qcow2

# qcow2 -> vmdk
qemu-img convert -f qcow2 -O vmdk input.qcow2 output.vmdk

# qcow2 -> raw
qemu-img convert -f qcow2 -O raw input.qcow2 output.img

# 查看镜像信息
qemu-img info image.qcow2
```

---

## 默认配置

| 项目 | 值 |
|------|-----|
| 管理地址 | 首次启动自动检测：若 WAN 口通过 DHCP 获取到 IP，LAN 口 IP 自动设为网关网段的 `.100`；否则默认为 `192.168.100.1` |
| 用户名 | `root` |
| 密码 | 无 |
| 默认磁盘大小 | 2GB |
| 架构 | ARM64 (aarch64) |
| 固件版本 | iStoreOS 24.10.x |

## 注意事项

- 固件基于 iStoreOS 官方 ImageBuilder 打包，默认自带 luci-app-store
- **创建虚拟机时必须禁用 Secure Boot**，否则系统无法引导
- 默认 Rootfs 大小 2048 MB，可在工作流参数中调整

## 致谢

本项目修改自 [wukongdaily/ImmortalWrt-ImageBuilder](https://github.com/wukongdaily/ImmortalWrt-ImageBuilder)，在其基础上适配了 iStoreOS ImageBuilder 构建流程。
