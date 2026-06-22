# iStoreOS ARM64 虚拟机固件使用指南

## 下载文件

下载完成后，你会得到两个文件：

| 文件 | 格式 | 适用平台 |
|------|------|----------|
| `*.qcow2` | QEMU Copy-On-Write | Armbian + KVM/QEMU, PVE, UTM |
| `*.vmdk` | VMware Virtual Disk | VMware, VirtualBox, PVE |

---

## 一、qcow2 在 Armbian + KVM 中使用

### 1. 安装 KVM 相关组件

```bash
# Armbian 系统下安装
sudo apt update
sudo apt install -y qemu-kvm virt-manager libvirt-daemon-system libvirt-clients bridge-utils
sudo systemctl enable --now libvirtd
```

### 2. 配置网桥（可选，用于给虚拟机分配独立 IP）

```bash
# 创建网桥 br0
sudo nmcli connection add type bridge ifname br0
sudo nmcli connection add type bridge-slave ifname eth0 master br0
sudo nmcli connection up br0
```

### 3. 创建并启动虚拟机

#### 方式一：使用 virt-install（推荐）

```bash
sudo virt-install \
  --name istoreos \
  --arch aarch64 \
  --vcpus 2 \
  --memory 1024 \
  --disk path=/path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.qcow2,format=qcow2,bus=virtio \
  --network bridge=br0,model=virtio \
  --import \
  --os-variant generic \
  --noautoconsole
```

#### 方式二：使用 qemu-system-aarch64 直接启动

```bash
sudo qemu-system-aarch64 \
  -M virt \
  -cpu cortex-a72 \
  -smp 2 \
  -m 1024 \
  -drive file=/path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.qcow2,format=qcow2,if=virtio \
  -netdev bridge,id=net0,br=br0 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
```

### 4. 访问管理界面

- 单网口模式：启动后自动 DHCP，在终端输入 `ip a` 查看获取到的 IP
- 多网口模式：第一个网口为 WAN（DHCP），其余自动桥接为 LAN，默认地址 `192.168.100.1`
- 浏览器访问 `http://192.168.100.1`，用户名 `root`，密码为空

### 5. 扩展磁盘大小

qcow2 支持在线扩展：

```bash
# 在宿主机上执行
sudo qemu-img resize /path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.qcow2 +4G
```

然后在 iStoreOS 内使用 `diskman` 或 `parted` 扩展分区。

---

## 二、vmdk 在其他平台使用

### 1. VMware Workstation / Player（x86_64 或 ARM 版）

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

### 2. VirtualBox

#### 方式一：直接使用 vmdk

```bash
VBoxManage createvm --name "iStoreOS" --ostype "Linux_ARM64" --register
VBoxManage modifyvm "iStoreOS" --memory 1024 --cpus 2
VBoxManage modifyvm "iStoreOS" --nic1 bridged --bridgeadapter1 eth0
VBoxManage storagectl "iStoreOS" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "iStoreOS" --storagectl "SATA" --port 0 --device 0 --type hdd --medium /path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.vmdk
VBoxManage startvm "iStoreOS"
```

#### 方式二：转换为 VirtualBox 原生格式（VDI）

```bash
VBoxManage clonehd /path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.vmdk /path/to/istoreos.vdi --format VDI
```

### 3. PVE (Proxmox Virtual Environment)

```bash
# 上传 vmdk 或 qcow2 到 PVE 节点的某个存储目录
# 创建虚拟机
qm create 100 --name istoreos --memory 1024 --cores 2 --net0 virtio,bridge=vmbr0

# 导入磁盘（支持 qcow2 和 vmdk）
qm importdisk 100 /path/to/istoreos-armsr-armv8-generic-squashfs-combined-efi.qcow2 local-lvm

# 将导入的磁盘设置为启动盘
qm set 100 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-100-disk-0
qm set 100 --boot order=scsi0
```

---

## 三、格式转换（使用 qemu-img）

如果需要在不同格式间互转：

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

## 四、默认配置

| 项目 | 值 |
|------|-----|
| 管理地址 | `192.168.100.1` |
| 用户名 | `root` |
| 密码 | 无 |
| 默认磁盘大小 | 2GB |
| 架构 | ARM64 (aarch64) |
| 固件版本 | iStoreOS 24.10.x |
