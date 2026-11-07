# Test betiklerinin ortak yardımcıları. Doğrudan çalıştırılmaz, diğer betikler yükler.

$ErrorActionPreference = "Stop"
$script:utf8 = [System.Text.Encoding]::UTF8
$script:gecen = 0
$script:kalan = 0
if (-not $script:Base) { $script:Base = "http://localhost:5678/webhook" }

function Invoke-Api([string]$Path, $Body, [string]$Token, [int]$TimeoutSec = 200) {
    $headers = @{}
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    $bytes = $script:utf8.GetBytes(($Body | ConvertTo-Json -Compress -Depth 10))
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $r = Invoke-WebRequest -Method Post -Uri "$script:Base/$Path" -Headers $headers -TimeoutSec $TimeoutSec `
            -ContentType "application/json; charset=utf-8" -Body $bytes -UseBasicParsing
        return @{ Status = [int]$r.StatusCode; Text = $script:utf8.GetString($r.RawContentStream.ToArray()); Ms = $sw.ElapsedMilliseconds }
    } catch {
        $resp = $_.Exception.Response
        if (-not $resp) { return @{ Status = 0; Text = "BAĞLANTI KURULAMADI: $($_.Exception.Message)"; Ms = $sw.ElapsedMilliseconds } }
        $text = $null
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $text = $_.ErrorDetails.Message }
        if (-not $text) {
            try {
                $stream = $resp.GetResponseStream()
                if ($stream.CanSeek) { $stream.Position = 0 }
                $text = (New-Object System.IO.StreamReader($stream, $script:utf8)).ReadToEnd()
            } catch { $text = "" }
        }
        return @{ Status = [int]$resp.StatusCode; Text = $text; Ms = $sw.ElapsedMilliseconds }
    }
}

# Check: yanıt JSON'unu alan ve $true/$false döndüren isteğe bağlı ek kontrol
function Test-Case {
    param([string]$Name, [string]$Path, $Body, [int]$Expected, [string]$Token,
          [scriptblock]$Check, [string]$CheckDesc = "ek kontrol")
    $r = Invoke-Api $Path $Body $Token
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

function Show-Reply($json) {
    if ($json -and $json.data -and $json.data.reply) {
        Write-Host "       [$($json.data.reply.model)] $($json.data.reply.content)" -ForegroundColor Cyan
    }
}

function Show-Summary([string]$What) {
    Write-Host ""
    if ($script:kalan -eq 0) {
        Write-Host "SONUÇ: $script:gecen / $($script:gecen + $script:kalan) test geçti. $What hazır." -ForegroundColor Green
    } else {
        Write-Host "SONUÇ: $script:kalan test kaldı. Bu ekranın görüntüsünü gönder." -ForegroundColor Red
    }
}

function New-TestUser {
    $email = "test$(Get-Random -Maximum 9999999)@ornek.com"
    $reg = Test-Case "Test kullanıcısı oluştur" "auth/register" @{ name = "Test Öğrenci"; email = $email; password = "gizli123" } 201
    if (-not $reg -or -not $reg.data.token) {
        Write-Host "Kullanıcı oluşturulamadı; 00-auth yayında mı?" -ForegroundColor Red
        exit 1
    }
    return $reg.data.token
}
