# 00-auth uç noktalarını test eder.
# Workflow yayınlanmış (Publish) olmalıdır.
# Çalıştırma (proje klasöründe, PowerShell veya cmd):
#   powershell -ExecutionPolicy Bypass -File scripts\test-auth.ps1

param([string]$Base = "http://localhost:5678/webhook")

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.Encoding]::UTF8
$script:gecen = 0
$script:kalan = 0

function Invoke-Api([string]$Path, $Body, [string]$Token) {
    $headers = @{}
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    $bytes = $utf8.GetBytes(($Body | ConvertTo-Json -Compress))
    try {
        $r = Invoke-WebRequest -Method Post -Uri "$Base/$Path" -Headers $headers `
            -ContentType "application/json; charset=utf-8" -Body $bytes -UseBasicParsing
        return @{ Status = [int]$r.StatusCode; Text = $utf8.GetString($r.RawContentStream.ToArray()) }
    } catch {
        $resp = $_.Exception.Response
        if (-not $resp) { return @{ Status = 0; Text = "BAĞLANTI KURULAMADI: $($_.Exception.Message)" } }
        # PowerShell 5.1 hata gövdesini akıştan okuyup ErrorDetails'e koyar
        $text = $null
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $text = $_.ErrorDetails.Message }
        if (-not $text) {
            try {
                $stream = $resp.GetResponseStream()
                if ($stream.CanSeek) { $stream.Position = 0 }
                $text = (New-Object System.IO.StreamReader($stream, $utf8)).ReadToEnd()
            } catch { $text = "" }
        }
        return @{ Status = [int]$resp.StatusCode; Text = $text }
    }
}

function Test-Case([string]$Name, [string]$Path, $Body, [int]$Expected, [string]$Token) {
    $r = Invoke-Api $Path $Body $Token
    $json = $null
    try { $json = $r.Text | ConvertFrom-Json } catch { }
    if ($r.Status -eq $Expected -and $json -ne $null) {
        $script:gecen++
        Write-Host ("GEÇTİ  {0,-38} {1}" -f $Name, $r.Status) -ForegroundColor Green
    } else {
        $script:kalan++
        Write-Host ("KALDI  {0,-38} beklenen {1}, gelen {2}" -f $Name, $Expected, $r.Status) -ForegroundColor Red
        Write-Host "       Yanıt: $($r.Text)" -ForegroundColor Yellow
    }
    return $json
}

Write-Host "Hedef: $Base`n"
$email = "test$(Get-Random -Maximum 999999)@ornek.com"

$reg = Test-Case "Kayıt (yeni kullanıcı)"            "auth/register" @{ name = "Test Öğrenci"; email = $email; password = "gizli,123" } 201
Test-Case "Kayıt (aynı e-posta)"                     "auth/register" @{ name = "Test"; email = $email; password = "gizli123" } 409 | Out-Null
Test-Case "Kayıt (geçersiz e-posta)"                 "auth/register" @{ name = "Test"; email = "yanlis"; password = "gizli123" } 400 | Out-Null
Test-Case "Kayıt (kısa şifre)"                       "auth/register" @{ name = "Test"; email = "x$email"; password = "123" } 400 | Out-Null
$login = Test-Case "Giriş (doğru şifre, virgüllü)"   "auth/login" @{ email = $email; password = "gizli,123" } 200
Test-Case "Giriş (yanlış şifre)"                     "auth/login" @{ email = $email; password = "yanlis" } 401 | Out-Null
Test-Case "Giriş (eksik alan)"                       "auth/login" @{ email = $email } 401 | Out-Null

if ($login -and $login.data.token) {
    Test-Case "Çıkış"                                "auth/logout" @{} 200 $login.data.token | Out-Null
} else {
    $script:kalan++
    Write-Host "KALDI  Çıkış                                   giriş token'ı alınamadığı için atlandı" -ForegroundColor Red
}

Write-Host ""
if ($script:kalan -eq 0) {
    Write-Host "SONUÇ: $script:gecen / $($script:gecen + $script:kalan) test geçti. 00-auth hazır." -ForegroundColor Green
} else {
    Write-Host "SONUÇ: $script:kalan test kaldı. Bu ekranın görüntüsünü gönder." -ForegroundColor Red
}
