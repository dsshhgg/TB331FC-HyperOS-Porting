# 脚本索引

所有脚本统一放在本目录。命名约定：

| 文件 | 用途 | 依赖 |
|------|------|------|
| `parse_super_lp.py` | 解析 ZUI super 的 **liblp 元数据**：逻辑分区清单、sectors、字节大小、group、extent 物理偏移 | Python 3 标准库 |
| `ext4_ls.py` | 纯 Python **只读 EXT4** 镜像遍历 / 列目录 / 导出单个文件（ZUI 侧分区为 EXT4） | Python 3 标准库 |
| `extract_props.py` | 扫描镜像 / 内核中的 `ro.*` / `androidboot.*` 属性与 `Linux version` banner | Python 3 标准库 |
| `verify_payload.py` | 解析 OTA `payload.bin` 的 DeltaArchiveManifest，列出分区大小/期望 sha256，并**校验**已抽取镜像 | Python 3 标准库（内置最小 protobuf 解析） |
| `unpack_zui.ps1` | 解包 ZUI boot/init_boot/vendor_boot，提取内核版本 | PowerShell + magiskboot |
| `unpack_hyperos.ps1` | 列出 HyperOS payload 分区，抽取 boot/system_dlkm | PowerShell + payload-dumper-go |
| `compare_partitions.py` | 分区/KMI/体积对比，输出可行性摘要 | Python 3 |
| `debloat_product.ps1` | product 精简（A 档打包用） | PowerShell |
| `pack_system_a.ps1` | 合成 system 镜像（EROFS） | PowerShell + mkfs.erofs |
| `build_super.sh` | （预留）重打包 super.img | lpmake |

## 约定

- 大镜像输入/输出指向 `E:\rom\port\hyperos\assets\`（仓库外）或 `E:\rom\port\hyperos\work\`
- 临时文件写 `tmp/`，产物写 `out/`
- **禁止**任何 fastboot flash / 分区写入脚本在未确认前执行
- 脚本头部注释必须包含：用途、时间、依赖、用法
- **分析类脚本必须零第三方依赖**（只用 Python 标准库），避免环境漂移
- 所有脚本对原厂固件**只读**，不得写入源目录

## 用法示例

```powershell
# ZUI super 逻辑分区表（输出含 extent 物理偏移）
python scripts/parse_super_lp.py "E:\类\刷机\联想\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image\super_1.img"

# ZUI 分区文件树（EXT4）
python scripts/ext4_ls.py "<...>\image\super_7.img" --out work\zui_trees\vendor_a.list.txt

# 属性取证
python scripts/extract_props.py --file "<...>\image\super_4.img" --out work\zui_props\system_a.txt

# 校验解包完整性
python scripts/verify_payload.py --payload "<...>\payload.bin" `
    --verify-dir "E:\rom\port\hyperos\assets\hyperos" --only system,system_ext,product,mi_ext,mi_product

# 原流程
powershell -File scripts/unpack_zui.ps1
powershell -File scripts/unpack_hyperos.ps1
python scripts/compare_partitions.py
```

## 已知工具局限

- `erofs-utils 1.8.10` 无法解析 `yupei` 的 `vendor.img` / `odm.img` 部分目录项
  （`bogus i_mode (0) @ nid ...`）。**这不是解包损坏**（sha256 与官方清单一致）。
  对 `system` / `system_ext` / `product` / `mi_ext` 解析正常。
- `payload-dumper-go` 抽取大分区（vendor 1.6 GiB / odm 1.5 GiB）耗时较长，
  **必须等进程结束并核对 sha256** 后再使用产物 —— 读取半成品会得到错误的解析结果
  （曾因此误判 `vendor.img` 哈希不匹配）。
