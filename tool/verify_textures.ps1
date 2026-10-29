Add-Type -AssemblyName System.Drawing

$base = "assets/textures/pbr_2k"
$pngFiles = Get-ChildItem -Path $base -Recurse -Filter "*.png"

$results = @()
foreach ($f in $pngFiles) {
    try {
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        $w = $img.Width
        $h = $img.Height
        $img.Dispose()
    } catch {
        $w = -1
        $h = -1
    }
    
    $results += [PSCustomObject]@{
        Folder = $f.Directory.Name
        Name = $f.Name
        Width = $w
        Height = $h
        SizeKB = [math]::Round($f.Length / 1024, 2)
    }
}

$results | Format-Table -AutoSize
