param([string]$AssetId = "Bricks113A")
Add-Type -AssemblyName System.IO.Compression.FileSystem
$url = "https://ambientcg.com/get?file=${AssetId}_1K-JPG.zip"
$tmp = [System.IO.Path]::GetTempFileName() + ".zip"
Write-Output "Downloading $url to $tmp ..."
Invoke-WebRequest -Uri $url -OutFile $tmp
$zip = [System.IO.Compression.ZipFile]::OpenRead($tmp)
$zip.Entries | Select-Object Name, Length
$zip.Dispose()
Remove-Item $tmp
