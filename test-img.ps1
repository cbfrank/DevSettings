
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Hide", "Extract")]
    [string]$Mode,
    
    [Parameter(Mandatory=$false)]
    [string]$RepoPath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputJpg,
    
    [Parameter(Mandatory=$false)]
    [string]$InputJpg,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [int]$SegmentSize = 65000
)

function Get-JpgHeader {
    $header = New-Object System.Collections.ArrayList
    
    $header.Add(0xFF) | Out-Null
    $header.Add(0xD8) | Out-Null
    
    $header.Add(0xFF) | Out-Null
    $header.Add(0xE0) | Out-Null
    $header.Add(0x00) | Out-Null
    $header.Add(0x10) | Out-Null 
    
    
    $jfif = [System.Text.Encoding]::ASCII.GetBytes("JFIF`0")
    $header.AddRange($jfif) | Out-Null
    
   
    $header.Add(0x01) | Out-Null
    $header.Add(0x01) | Out-Null
    
    
    $header.Add(0x00) | Out-Null
    
    
    $header.Add(0x00) | Out-Null
    $header.Add(0x01) | Out-Null
    
    
    $header.Add(0x00) | Out-Null
    $header.Add(0x01) | Out-Null
    
    
    $header.Add(0x00) | Out-Null  
    $header.Add(0x00) | Out-Null  
    
    
    $header.Add(0xFF) | Out-Null
    $header.Add(0xDB) | Out-Null
    $header.Add(0x00) | Out-Null
    $header.Add(0x43) | Out-Null 
    $header.Add(0x00) | Out-Null  
    
    
    for ($i = 0; $i -lt 64; $i++) {
        $header.Add(0x10) | Out-Null
    }
    
    
    $header.Add(0xFF) | Out-Null
    $header.Add(0xC0) | Out-Null
    $header.Add(0x00) | Out-Null
    $header.Add(0x0B) | Out-Null  
    $header.Add(0x08) | Out-Null  
    
    
    $header.Add(0x00) | Out-Null
    $header.Add(0x10) | Out-Null  
    
    
    $header.Add(0x00) | Out-Null
    $header.Add(0x10) | Out-Null  
    
    
    $header.Add(0x01) | Out-Null  
    
    
    $header.Add(0x01) | Out-Null  
    $header.Add(0x11) | Out-Null  
    $header.Add(0x00) | Out-Null 
    
    
    $header.Add(0xFF) | Out-Null
    $header.Add(0xC4) | Out-Null
    $header.Add(0x00) | Out-Null
    $header.Add(0x14) | Out-Null  
    $header.Add(0x00) | Out-Null  
    
    
    for ($i = 0; $i -lt 16; $i++) {
        $header.Add(0x00) | Out-Null
    }
    $header.Add(0x01) | Out-Null  
    
    return $header.ToArray()
}


function Get-SosMarker {
    param([int]$DataLength)
    
    $sos = New-Object System.Collections.ArrayList
    
    
    $sos.Add(0xFF) | Out-Null
    $sos.Add(0xDA) | Out-Null
    
    
    $sos.Add(0x00) | Out-Null
    $sos.Add(0x08) | Out-Null 
    
    
    $sos.Add(0x01) | Out-Null
    
    
    $sos.Add(0x01) | Out-Null 
    $sos.Add(0x00) | Out-Null  
    
    
    $sos.Add(0x00) | Out-Null
    
    
    $sos.Add(0x3F) | Out-Null
    
    
    $sos.Add(0x00) | Out-Null
    
    return $sos.ToArray()
}


function Get-JpgFooter {
    
    return [byte[]]@(0xFF, 0xD9)
}


function Escape-JpgData {
    param([byte[]]$Data)
    
    $escaped = New-Object System.Collections.ArrayList
    
    foreach ($byte in $Data) {
        $escaped.Add($byte) | Out-Null
        
        if ($byte -eq 0xFF) {
            $escaped.Add(0x00) | Out-Null
        }
    }
    
    return $escaped.ToArray()
}


function Unescape-JpgData {
    param([byte[]]$Data)
    
    $unescaped = New-Object System.Collections.ArrayList
    $i = 0
    
    while ($i -lt $Data.Length) {
        $byte = $Data[$i]
        $unescaped.Add($byte) | Out-Null
        
       
        if ($byte -eq 0xFF -and ($i + 1) -lt $Data.Length -and $Data[$i + 1] -eq 0x00) {
            $i++  
        }
        
        $i++
    }
    
    return $unescaped.ToArray()
}


function Hide-RepoInJpg {
    param(
        [string]$RepoPath,
        [string]$OutputJpg,
        [int]$SegmentSize
    )
    
   
    
    
    if (-not (Test-Path $RepoPath)) {
        
        return
    }
    
    
    $gitDir = Join-Path $RepoPath ".git"
    if (-not (Test-Path $gitDir)) {
        
        return
    }
    
    
    Push-Location $RepoPath
    $trackedFiles = git ls-files
    Pop-Location
    
    if ($trackedFiles.Count -eq 0) {
        
        return
    }
    
   
    
    
    $tempZip = [System.IO.Path]::GetTempFileName() + ".zip"
    
    try {
        
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        if (Test-Path $tempZip) {
            Remove-Item $tempZip -Force
        }
        
        $zip = [System.IO.Compression.ZipFile]::Open($tempZip, 'Create')
        
        foreach ($file in $trackedFiles) {
            $fullPath = Join-Path $RepoPath $file
            if (Test-Path $fullPath) {
                $entryName = $file.Replace('\', '/')
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $fullPath, $entryName) | Out-Null
                
            }
        }
        
        $zip.Dispose()
        
       
        $zipData = [System.IO.File]::ReadAllBytes($tempZip)
        
        
        
        $marker = [System.Text.Encoding]::UTF8.GetBytes("GITDATA")
        $dataLength = [System.BitConverter]::GetBytes([int64]$zipData.Length)
        
        $payload = New-Object System.Collections.ArrayList
        $payload.AddRange($marker) | Out-Null
        $payload.AddRange($dataLength) | Out-Null
        $payload.AddRange($zipData) | Out-Null
        
        $payloadBytes = $payload.ToArray()
        
       
        
        
        $segments = New-Object System.Collections.ArrayList
        $offset = 0
        $segmentCount = 0
        
        while ($offset -lt $payloadBytes.Length) {
            $length = [Math]::Min($SegmentSize, $payloadBytes.Length - $offset)
            $segment = $payloadBytes[$offset..($offset + $length - 1)]
            
            
            $escapedSegment = Escape-JpgData -Data $segment
            
            $segments.Add($escapedSegment) | Out-Null
            $segmentCount++
            
           
            
            $offset += $length
        }
        
        
        
        
        
        $jpgFile = New-Object System.Collections.ArrayList
        
        
        $header = Get-JpgHeader
        $jpgFile.AddRange($header) | Out-Null
        
        
        foreach ($segment in $segments) {
            
            $sos = Get-SosMarker
            $jpgFile.AddRange($sos) | Out-Null
            
           
            $jpgFile.AddRange($segment) | Out-Null
        }
        
        
        $footer = Get-JpgFooter
        $jpgFile.AddRange($footer) | Out-Null
        
        
        [System.IO.File]::WriteAllBytes($OutputJpg, $jpgFile.ToArray())
        
        $fileInfo = Get-Item $OutputJpg
        
        
    } finally {
        
        if (Test-Path $tempZip) {
            Remove-Item $tempZip -Force
        }
    }
}

function Extract-RepoFromJpg {
    param(
        [string]$InputJpg,
        [string]$OutputPath
    )
    
    
    
    
    if (-not (Test-Path $InputJpg)) {
        
        return
    }
    
    
    $jpgData = [System.IO.File]::ReadAllBytes($InputJpg)
    
    
    
    $segments = New-Object System.Collections.ArrayList
    $i = 0
    
    
    
    while ($i -lt $jpgData.Length - 1) {
        
        if ($jpgData[$i] -eq 0xFF -and $jpgData[$i + 1] -eq 0xDA) {
            
           
            $i += 10
           
            $segmentData = New-Object System.Collections.ArrayList
            
            while ($i -lt $jpgData.Length - 1) {
                $byte = $jpgData[$i]
                
               
                if ($byte -eq 0xFF -and $jpgData[$i + 1] -ne 0x00) {
                    
                    break
                }
                
                $segmentData.Add($byte) | Out-Null
                $i++
            }
            
            if ($segmentData.Count -gt 0) {
                $segments.Add($segmentData.ToArray()) | Out-Null
               
            }
        } else {
            $i++
        }
    }
    
    
    
    if ($segments.Count -eq 0) {
        
        return
    }
    
   
    $allData = New-Object System.Collections.ArrayList
    
    foreach ($segment in $segments) {
        $unescaped = Unescape-JpgData -Data $segment
        $allData.AddRange($unescaped) | Out-Null
    }
    
    $totalData = $allData.ToArray()
    
    
    
    $marker = [System.Text.Encoding]::UTF8.GetBytes("GITDATA")
    $markerMatch = $true
    
    for ($i = 0; $i -lt $marker.Length; $i++) {
        if ($totalData[$i] -ne $marker[$i]) {
            $markerMatch = $false
            break
        }
    }
    
    if (-not $markerMatch) {
       
        return
    }
    
   
    
    $lengthBytes = $totalData[$marker.Length..($marker.Length + 7)]
    $dataLength = [System.BitConverter]::ToInt64([byte[]]$lengthBytes, 0)
    
    
    
    
    $dataStart = $marker.Length + 8
    $dataEnd = $dataStart + $dataLength - 1
    
    if ($dataEnd -ge $totalData.Length) {
       
        return
    }
    
    $zipData = $totalData[$dataStart..$dataEnd]
    
    
    $tempZip = [System.IO.Path]::GetTempFileName() + ".zip"
    
    try {
       
        [System.IO.File]::WriteAllBytes($tempZip, $zipData)
        
        
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $testZip = [System.IO.Compression.ZipFile]::OpenRead($tempZip)
            $entryCount = $testZip.Entries.Count
            $testZip.Dispose()
            
        } catch {
           
            return
        }
        
        
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
       
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $OutputPath, $true)
        
       
        $extractedFiles = Get-ChildItem -Path $OutputPath -Recurse -File
       
        $extractedFiles | Select-Object -First 20 | ForEach-Object {
            $relativePath = $_.FullName.Substring($OutputPath.Length).TrimStart('\', '/')
            Write-Host "  $relativePath" -ForegroundColor Gray
        }
        
        
        
    } finally {
        
        if (Test-Path $tempZip) {
            Remove-Item $tempZip -Force
        }
    }
}


try {
    if ($Mode -eq "Hide") {
        if (-not $RepoPath -or -not $OutputJpg) {
            
            return
        }
        Hide-RepoInJpg -RepoPath $RepoPath -OutputJpg $OutputJpg -SegmentSize $SegmentSize
    }
    elseif ($Mode -eq "Extract") {
        if (-not $InputJpg -or -not $OutputPath) {
           
            return
        }
        Extract-RepoFromJpg -InputJpg $InputJpg -OutputPath $OutputPath
    }
}
catch {
    Write-Error "发生错误: $_"
    Write-Error $_.ScriptStackTrace
}
