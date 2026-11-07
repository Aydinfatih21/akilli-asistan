# 10-courses ve 01-chat uç noktalarını uçtan uca test eder.
# 00-auth, 10-courses ve 01-chat yayınlanmış (Publish) olmalıdır.
# Çalıştırma (proje klasöründe):
#   powershell -ExecutionPolicy Bypass -File scripts\test-chat.ps1
# Farklı ikinci model denemek için:
#   powershell -ExecutionPolicy Bypass -File scripts\test-chat.ps1 -Model2 qwen2.5:7b

param([string]$Base = "http://localhost:5678/webhook", [string]$Model2 = "gemma3:4b")
$script:Base = $Base
. "$PSScriptRoot\_common.ps1"

$foreign = '[぀-ヿ㐀-䶿一-鿿가-힯Ѐ-ӿ]'

Write-Host "Hedef: $Base`n"
$tok = New-TestUser

Write-Host "`n--- Dersler (10-courses)"
Test-Case "Ders listesi (token yok)"          "courses/list"   @{} 401 | Out-Null
$c = Test-Case "Ders ekle"                     "courses/create" @{ name = "Mobil Programlama" } 201 $tok `
        -Check { param($j) $j.data.course.id } -CheckDesc "ders id'si"
$courseId = if ($c) { $c.data.course.id } else { $null }
Test-Case "Ders ekle (aynı ad)"               "courses/create" @{ name = "Mobil Programlama" } 409 $tok | Out-Null
Test-Case "Ders ekle (boş ad)"                "courses/create" @{ name = "   " } 400 $tok | Out-Null
Test-Case "Ders listesi"                      "courses/list"   @{} 200 $tok `
        -Check { param($j) @($j.data.courses).Count -eq 1 -and $j.data.courses[0].note_count -eq 0 } -CheckDesc "1 ders, 0 not" | Out-Null

Write-Host "`n--- Sohbet hataları (01-chat)"
Test-Case "Soru (token yok)"                  "chat/send" @{ message = "Merhaba" } 401 | Out-Null
Test-Case "Soru (boş mesaj)"                  "chat/send" @{ message = "  " } 400 $tok | Out-Null
Test-Case "Soru (olmayan sohbet)"             "chat/send" @{ message = "Merhaba"; conversation_id = [guid]::NewGuid().ToString() } 404 $tok | Out-Null
Test-Case "Soru (olmayan ders)"               "chat/send" @{ message = "Merhaba"; course_id = [guid]::NewGuid().ToString() } 404 $tok | Out-Null

Write-Host "`n--- Yapay zekâ ile soru-cevap (ilk istek model yüklendiği için yavaş olabilir)"
$a = Test-Case "Genel soru (varsayılan model)" "chat/send" @{ message = "Flutter nedir? İki cümleyle açıkla." } 200 $tok `
        -Check { param($j) $j.data.reply.content -and $j.data.reply.content -notmatch $foreign } -CheckDesc "Türkçe ve boş olmayan yanıt"
Show-Reply $a
$convId = if ($a) { $a.data.conversation_id } else { $null }

$b = Test-Case "Devam sorusu (aynı sohbet)" "chat/send" @{ message = "Bunu tek satırlık bir Dart örneğiyle göster."; conversation_id = $convId } 200 $tok `
        -Check { param($j) $j.data.conversation_id -eq $convId -and $j.data.reply.content -notmatch $foreign } -CheckDesc "aynı sohbet, Türkçe yanıt"
Show-Reply $b

$m = Test-Case "Derse bağlı soru ($Model2)" "chat/send" @{ message = "Stateless ve stateful widget farkı nedir?"; course_id = $courseId; model = $Model2 } 200 $tok `
        -Check { param($j) $j.data.reply.model -like "$Model2*" -and $j.data.reply.content -notmatch $foreign } -CheckDesc "seçilen model, Türkçe yanıt"
Show-Reply $m

Write-Host "`n--- Sohbet geçmişi"
Test-Case "Sohbet listesi"                    "chat/conversations" @{} 200 $tok `
        -Check { param($j) @($j.data.conversations).Count -eq 2 } -CheckDesc "2 sohbet" | Out-Null
Test-Case "Sohbet listesi (ders filtresi)"    "chat/conversations" @{ course_id = $courseId } 200 $tok `
        -Check { param($j) @($j.data.conversations).Count -eq 1 } -CheckDesc "1 sohbet" | Out-Null
Test-Case "Sohbet geçmişi"                    "chat/history" @{ conversation_id = $convId } 200 $tok `
        -Check { param($j) @($j.data.messages).Count -eq 4 } -CheckDesc "4 mesaj (2 soru + 2 yanıt)" | Out-Null
Test-Case "Sohbet geçmişi (olmayan)"          "chat/history" @{ conversation_id = [guid]::NewGuid().ToString() } 404 $tok | Out-Null

Show-Summary "Dersler ve soru-cevap"
