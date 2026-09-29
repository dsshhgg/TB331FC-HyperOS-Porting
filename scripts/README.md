# 脚本索引

所有脚本统一放在本目录。命名约定：

| 文件 | 用途 |
|------|------|
| `unpack_zui.ps1` | 解包 ZUI boot/init_boot/vendor_boot，提取内核版本 |
| `unpack_hyperos.ps1` | 列出 HyperOS payload 分区，抽取 boot/system_dlkm |
| `compare_partitions.py` | 分区/KMI/体积对比，输出可行性摘要 |
| `extract_props.py` | 扫描镜像中的 ro.* / androidboot.* 属性 |
| `build_super.sh` | （预留）重打包 super.img |

## 约定

- 大镜像输入/输出指向 `E:\rom\port\hyperos\assets\`（仓库外）或 `E:\rom\port\hyperos\work\`
- 临时文件写 `tmp/`，产物写 `out/`
- **禁止**任何 fastboot flash / 分区写入脚本在未确认前执行
- 脚本头部注释必须包含：用途、时间、依赖、用法

## 用法示例

```powershell
powershell -File scripts/unpack_zui.ps1
powershell -File scripts/unpack_hyperos.ps1
python scripts/compare_partitions.py
python scripts/extract_props.py --dir "E:\类\刷机\联想\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image"
```
