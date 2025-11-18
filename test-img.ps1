# 从图片中还原 zip 文件
# 用法: .\restore-from-image.ps1 <图片文件名> <原始zip大小>

param(
    [Parameter(Mandatory=$true)]
    [string]$ImageFile,
    
    [Parameter(Mandatory=$true)]
    [int]$OriginalSize
)

if (-not (Test-Path $ImageFile)) {
    Write-Host "错误: 文件不存在 - $ImageFile" -ForegroundColor Red
    exit 1
}

Add-Type -AssemblyName System.Drawing

# 加载图片
$bmp = New-Object System.Drawing.Bitmap($ImageFile)
$width = $bmp.Width
$height = $bmp.Height

# 从像素中提取数据
$zipBytes = New-Object byte[] $OriginalSize
$dataIndex = 0

for ($y = 0; $y -lt $height -and $dataIndex -lt $OriginalSize; $y++) {
    for ($x = 0; $x -lt $width -and $dataIndex -lt $OriginalSize; $x++) {
        $pixel = $bmp.GetPixel($x, $y)
        
        if ($dataIndex -lt $OriginalSize) {
            $zipBytes[$dataIndex++] = $pixel.R
        }
        if ($dataIndex -lt $OriginalSize) {
            $zipBytes[$dataIndex++] = $pixel.G
        }
        if ($dataIndex -lt $OriginalSize) {
            $zipBytes[$dataIndex++] = $pixel.B
        }
    }
}

$bmp.Dispose()

# 生成输出文件名
$outputName = "output-$(Get-Date -Format 'yyyyMMdd-HHmmss').z"

# 写入 zip 文件
[System.IO.File]::WriteAllBytes((Join-Path $PWD $outputName), $zipBytes)

Write-Host "ok: $outputName" -ForegroundColor Green
Write-Host "$dataIndex 字节数据" -ForegroundColor Green
