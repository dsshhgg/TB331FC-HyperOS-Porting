# pack_system_a.ps1
# 用途：将 debloat 后的 system/product/system_ext(/mi_ext) 打包为可刷 system 镜像
# 时间：2026-09-29
# 依赖：mkfs.erofs.exe（E:\rom\$dir\mkfs.erofs.exe）
# 用法：powershell -File scripts/pack_system_a.ps1 -Mode A
#       powershell -File scripts/pack_system_a.ps1 -Mode B -IncludeMiExt
# 说明：只写 out\，不执行 fastboot

param(
    [ValidateSet('A','B')]
    [string]$Mode = 'A',
    [switch]$IncludeMiExt,
    [string]$Trees = 'E:\rom\port\hyperos\work\trusted_trees',
    [string]$OutDir = 'E:\rom\port\hyperos\out',
    [string]$Mkfs = 'E:\rom\port\tools\erofs\new\mkfs.erofs.exe'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# A档目标 < 4.5 GiB；B档 4.5–5.5 GiB（需 resize-logical-partition）
if ($Mode -eq 'A') { $TargetMB = 4608 } else { $TargetMB = 5632 }

# 合并树：以 product 根为 /，再并入 system / system_ext / mi_ext
# HyperOS 常见布局：/system 为根；此处做「单分区合并」便于塞进 system_a
$merge = Join-Path $OutDir 'merge_root'
if (Test-Path $merge) { Remove-Item $merge -Recurse -Force }
New-Item -ItemType Directory -Force -Path $merge | Out-Null

function Copy-Tree([string]$src, [string]$dst) {
    if (-not (Test-Path $src)) { Write-Host "  skip missing $src"; return }
    Write-Host "  merge $src -> $dst"
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    # robocopy mirror
    & robocopy $src $dst /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed $src" }
    $global:LASTEXITCODE = 0
}

Write-Host "Building merge tree (Mode=$Mode)..."
# 解包布局: trees/system/{config,system}, trees/product/{config,product}, ...
# 合并为单镜像: /  <- system 内容; /product; /system_ext
function Resolve-Root([string]$base, [string]$name) {
    # 优先选含 build.prop 的最深一层：
    #   system.img 根含 /system 子目录(system-as-root 合并布局) -> 内容在 3 层
    #   product/system_ext/mi_ext 根即内容 -> 内容在 2 层
    # 注意：etc/app/bin 在镜像根可能是符号链接，不能作为判据
    $candidates = @(
        (Join-Path $base "$name\$name\$name"),
        (Join-Path $base "$name\$name"),
        (Join-Path $base $name),
        $base
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'build.prop')) { return $c }
    }
    foreach ($c in $candidates) {
        $ok = (Test-Path (Join-Path $c 'etc')) -or
              (Test-Path (Join-Path $c 'app')) -or
              (Test-Path (Join-Path $c 'priv-app')) -or
              (Test-Path (Join-Path $c 'bin'))
        if ($ok) { return $c }
    }
    return (Join-Path $base $name)
}

$sysRoot = Resolve-Root (Join-Path $Trees 'system') 'system'
$prodRoot = Resolve-Root (Join-Path $Trees 'product') 'product'
$sxRoot = Resolve-Root (Join-Path $Trees 'system_ext') 'system_ext'
Write-Host "  roots: sys=$sysRoot prod=$prodRoot sx=$sxRoot"

Copy-Tree $sysRoot $merge

# 移除 system 内容里的分区挂载点符号链接工件（extract.erofs 以 Cygwin <symlink> 文件形式抽出）：
#   product -> /product、system_ext -> /system_ext 与合并目标目录撞名，robocopy 会报
#   「ERROR 267 目录名无效」；它们是分区挂载点而非内容，不应作为文件留在合并镜像根。
#   media -> /product/media、vendor -> /vendor 不撞名且忠实于原镜像布局，保留。
foreach ($mp in @('product','system_ext')) {
    $mpPath = Join-Path $merge $mp
    if (Test-Path -LiteralPath $mpPath) {
        $item = Get-Item -LiteralPath $mpPath -Force
        if (-not $item.PSIsContainer) {
            Remove-Item -LiteralPath $mpPath -Force
            Write-Host "  removed mount-point symlink artifact: $mp"
        }
    }
}

Copy-Tree $prodRoot (Join-Path $merge 'product')
Copy-Tree $sxRoot (Join-Path $merge 'system_ext')
if ($IncludeMiExt) {
    $miRoot = Resolve-Root (Join-Path $Trees 'mi_ext') 'mi_ext'
    Copy-Tree $miRoot (Join-Path $merge 'mi_ext')
}

# TB331FC 设备特征
$xmlSrc = 'E:\rom\port\work\patches\TB331FC.xml'
$xmlDst = Join-Path $merge 'product\etc\device_features\TB331FC.xml'
if (Test-Path $xmlSrc) {
    New-Item -ItemType Directory -Force -Path (Split-Path $xmlDst) | Out-Null
    Copy-Item $xmlSrc $xmlDst -Force
    Write-Host "  injected TB331FC.xml"
}

$bytes = (Get-ChildItem $merge -Recurse -File | Measure-Object Length -Sum).Sum
$mb = [math]::Round($bytes / 1MB, 1)
Write-Host "Merge tree size: $mb MB (target $TargetMB MB)"
if ($mb -gt $TargetMB) {
    Write-Host "WARN: merge tree exceeds ${Mode}-tier raw budget; packed EROFS may still fit"
}

$img = Join-Path $OutDir "system_a_hyperos4_${Mode}.img"
Write-Host "mkfs.erofs -> $img"
# quote -z arg so PowerShell does not split on comma
& $Mkfs '-zlz4hc,9' '-T8' $img $merge 2>&1 | Select-Object -Last 15

if (Test-Path $img) {
    $isz = (Get-Item $img).Length
    Write-Host ("IMAGE: {0}  {1} MB  ({2} GiB)" -f $img, [math]::Round($isz/1MB,1), [math]::Round($isz/1GB,2))
    $targetBytes = $TargetMB * 1MB
    if ($isz -le $targetBytes) {
        Write-Host "PASS: within ${Mode}-tier budget"
    } else {
        Write-Host "FAIL: exceeds ${Mode}-tier budget, continue debloat"
    }
    (Get-FileHash $img -Algorithm MD5).Hash | Out-File (Join-Path $OutDir 'MD5SUMS.txt') -Encoding utf8
} else {
    Write-Host "mkfs failed"
}
