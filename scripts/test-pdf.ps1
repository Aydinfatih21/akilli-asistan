# PDF yükleme uç noktasını (/notes/extract-pdf) gerçek bir PDF ile test eder.
# 00-auth ve 02-notes yayınlanmış olmalıdır. Windows 10+ ile gelen curl.exe kullanılır.
# Çalıştırma (proje klasöründe):
#   powershell -ExecutionPolicy Bypass -File scripts\test-pdf.ps1

param([string]$Base = "http://localhost:5678/webhook", [string]$Pdf = "")
$script:Base = $Base
. "$PSScriptRoot\_common.ps1"
if (-not $Pdf) { $Pdf = Join-Path $PSScriptRoot "..\docs\ornek-notlar\turev.pdf" }
$Pdf = (Resolve-Path $Pdf).Path

function Send-File([string]$Path, [string]$Token) {
    $out = [System.IO.Path]::GetTempFileName()
    $curlArgs = @("-s", "-o", $out, "-w", "%{http_code}", "-X", "POST", "-F", "file=@$Path")
    if ($Token) { $curlArgs += @("-H", "Authorization: Bearer $Token") }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $code = & curl.exe @curlArgs "$script:Base/notes/extract-pdf"
    $text = [System.IO.File]::ReadAllText($out, $script:utf8)
    Remove-Item $out -ErrorAction SilentlyContinue
    return @{ Status = [int]$code; Text = $text; Ms = $sw.ElapsedMilliseconds }
}

function Test-File([string]$Name, [string]$Path, [string]$Token, [int]$Expected, [scriptblock]$Check, [string]$CheckDesc = "ek kontrol") {
    $r = Send-File $Path $Token
    $json = $null
    try { $json = $r.Text | ConvertFrom-Json } catch { }
    $problem = $null
    if ($r.Status -ne $Expected) { $problem = "beklenen $Expected, gelen $($r.Status)" }
    elseif ($json -eq $null) { $problem = "yanıt JSON değil" }
    elseif ($Check -and -not (& $Check $json)) { $problem = "$CheckDesc sağlanmadı" }
    $sure = "{0:N1} sn" -f ($r.Ms / 1000)
    if (-not $problem) {
        $script:gecen++
        Write-Host ("GEÇTİ  {0,-44} {1}  ({2})" -f $Name, $r.Status, $sure) -ForegroundColor Green
    } else {
        $script:kalan++
        Write-Host ("KALDI  {0,-44} {1}  ({2})" -f $Name, $problem, $sure) -ForegroundColor Red
        Write-Host "       Yanıt: $($r.Text)" -ForegroundColor Yellow
    }
    return $json
}

Write-Host "Hedef: $Base"
Write-Host "PDF:   $Pdf`n"
$tok = New-TestUser

$j = Test-File "Örnek PDF → metin" $Pdf $tok 200 `
    -Check { param($j) $j.data.text.Length -gt 500 -and $j.data.pages -eq 2 -and $j.data.text.Contains("Zincir kuralı") } `
    -CheckDesc "metin > 500 karakter, 2 sayfa, Türkçe karakterler doğru"
if ($j -and $j.data) {
    Write-Host ("       {0} karakter, {1} sayfa, başlık: {2}" -f $j.data.characters, $j.data.pages, $j.data.title) -ForegroundColor Cyan
    $ilk = $j.data.text.Substring(0, [Math]::Min(160, $j.data.text.Length))
    Write-Host "       $ilk…" -ForegroundColor Cyan
}

$txt = Join-Path $env:TEMP "asistan-test.txt"
[System.IO.File]::WriteAllText($txt, "Bu bir PDF değil.", $script:utf8)
Test-File "PDF olmayan dosya" $txt $tok 400 -Check { param($j) $j.error.code -eq "VALIDATION_ERROR" } | Out-Null

$bozuk = Join-Path $env:TEMP "asistan-bozuk.pdf"
[System.IO.File]::WriteAllText($bozuk, "bozuk içerik", $script:utf8)
Test-File "Bozuk PDF" $bozuk $tok 422 -Check { param($j) $j.error.code -eq "PDF_UNREADABLE" } | Out-Null

Test-File "Token yok" $Pdf "" 401 | Out-Null
Remove-Item $txt, $bozuk -ErrorAction SilentlyContinue

Show-Summary "PDF yükleme"
