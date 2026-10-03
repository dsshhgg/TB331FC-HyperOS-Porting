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
| `pack_system_a.ps1` | 合成 system 镜像（EROFS）。默认树 `work/trusted_trees`，`-Mkfs` 指向 `tools/erofs/new/mkfs.erofs.exe` | PowerShell + mkfs.erofs |
| `backup_partitions.ps1` | **试刷前分区只读导出**（备份）。默认 dry-run，`-Execute` 才执行；只读设备，不写任何分区 | PowerShell + adb / fastboot |
| `build_super.sh` | （预留）重打包 super.img | lpmake |

## ⚠️ 脚本编码约定（重要）

本目录所有 `.ps1` **必须为 UTF-8 with BOM**。

Windows PowerShell 5.1 对无 BOM 的 UTF-8 文件按 ANSI/GBK 解码，中文注释会被误解析，
产生**虚假的语法错误**（如 `Unexpected token '}'`），而文件本身语法完全正确。

```powershell
# 批量补 BOM
Get-ChildItem scripts\*.ps1 | ForEach-Object {
  $b = [IO.File]::ReadAllBytes($_.FullName)
  if (-not ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) {
    $t = [Text.Encoding]::UTF8.GetString($b)
    [IO.File]::WriteAllBytes($_.FullName, ([byte[]](0xEF,0xBB,0xBF)) + [Text.Encoding]::UTF8.GetBytes($t))
  }
}
```

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

# 重解可信树（完成后必须与镜像侧条目数对照，见「已知工具局限」）
extract.erofs -i assets\hyperos\system.img -x -o work\trusted_trees\system -s

# A 档镜像重建（可信树；先 debloat 再打包）
powershell -ExecutionPolicy Bypass -File scripts/debloat_product.ps1 `
    -Tree work\trusted_trees\product\product
powershell -ExecutionPolicy Bypass -File scripts/pack_system_a.ps1 `
    -Mode A -Trees work\trusted_trees -Mkfs tools\erofs\new\mkfs.erofs.exe

# 试刷前备份（默认 dry-run；加 -Execute 才真正执行，且只读设备）
powershell -ExecutionPolicy Bypass -File scripts/backup_partitions.ps1

# 原流程
powershell -File scripts/unpack_zui.ps1
powershell -File scripts/unpack_hyperos.ps1
python scripts/compare_partitions.py
```

## 已知工具局限

- **`extract.erofs` 抽出的树必须校验完整性，不可直接信**
  （2026-10 实测：`system.img` 抽出 3,621 个文件，重新解包得 4,582 个，
  **少 961 个**——含 `lib64` 495 个 `.so`、`usr/keylayout` 189 个、`usr/idc` 27 个）。
  缺件不仅导致误判，还会**掩盖构建 bug**（挂载点符号链接撞名在缺件树上不会触发）。
  → 每次解包后**必须与镜像侧条目数对照**：
  ```powershell
  extract.erofs -i <part>.img -p            # 打印镜像内全部条目
  (Get-ChildItem <tree> -Recurse -File).Count   # 与「条目数 - 目录数」比对
  ```
  推荐输出到 `work/trusted_trees/`，与旧的 `work/trees/` 区分。
- `erofs-utils 1.8.10` 无法解析 `yupei` 的 `vendor.img` / `odm.img` 部分目录项
  （`bogus i_mode (0) @ nid ...`）。**这不是解包损坏**（sha256 与官方清单一致）。
  对 `system` / `system_ext` / `product` / `mi_ext` 解析正常。
- `extract.erofs` 把符号链接抽成 **Cygwin `<symlink>` 文件**（内容为
  `!<symlink>` + UTF-16 目标，带 System 属性）。`mkfs.erofs` 能读回成符号链接，
  但 `robocopy` 只会把它们当普通文件复制——**若其名称与目标目录撞名，robocopy 报
  `ERROR 267 (0x10B) The directory name is invalid`**。
  `system.img` 根即含 `product→/product`、`system_ext→/system_ext` 两个撞名项。
- `payload-dumper-go` 抽取大分区（vendor 1.6 GiB / odm 1.5 GiB）耗时较长，
  **必须等进程结束并核对 sha256** 后再使用产物 —— 读取半成品会得到错误的解析结果
  （曾因此误判 `vendor.img` 哈希不匹配）。
