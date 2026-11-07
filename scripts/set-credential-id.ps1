# Workflow dosyalarındaki MongoDB credential kimliğini, n8n'de oluşturduğunuz
# "Asistan Mongo" credential'ının kimliğiyle değiştirir. Böylece içe aktarınca
# MongoDB düğümlerinde credential'ı tek tek seçmeniz gerekmez.
# Kullanım (proje klasöründe):
#   powershell -ExecutionPolicy Bypass -File scripts\set-credential-id.ps1 -Id <KIMLIK>
param([Parameter(Mandatory = $true)][string]$Id)

$utf8 = New-Object System.Text.UTF8Encoding($false)   # BOM'suz (n8n JSON'u böyle okur)
$pattern = '("mongoDb":\s*\{\s*"id":\s*")[^"]*(")'
$files = Get-ChildItem -Path (Join-Path $PSScriptRoot "..\n8n\workflows") -Filter *.json
foreach ($f in $files) {
    $text = [System.IO.File]::ReadAllText($f.FullName, $utf8)
    $count = ([regex]::Matches($text, $pattern)).Count
    if ($count -gt 0) {
        $text = [regex]::Replace($text, $pattern, { param($m) $m.Groups[1].Value + $Id + $m.Groups[2].Value })
        [System.IO.File]::WriteAllText($f.FullName, $text, $utf8)
    }
    Write-Host ("{0,-20} {1} MongoDB düğümü güncellendi" -f $f.Name, $count) -ForegroundColor Green
}
Write-Host "`nŞimdi workflow'ları n8n'e içe aktarabilirsiniz."
