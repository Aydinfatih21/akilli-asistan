# Canlı demo senaryosunu uçtan uca test eder:
#   ders notu gönder → özet al → aynı nottan test oluştur → testi çöz (en az bir yanlış) → kişisel öneri
# 00-auth, 10-courses, 02-notes, 03-quiz-generate, 04-quiz-evaluate yayınlanmış olmalıdır.
# Çalıştırma (proje klasöründe):
#   powershell -ExecutionPolicy Bypass -File scripts\test-notes-quiz.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\test-notes-quiz.ps1 -Model gemma3:4b

param([string]$Base = "http://localhost:5678/webhook", [string]$Model = "")
$script:Base = $Base
. "$PSScriptRoot\_common.ps1"

$foreign = '[぀-ヿ㐀-䶿一-鿿가-힯Ѐ-ӿ]'
$note = @"
Flutter, Google tarafından geliştirilen açık kaynaklı bir kullanıcı arayüzü araç setidir. Flutter uygulamaları Dart programlama diliyle yazılır ve tek bir kod tabanından Android, iOS, web ve masaüstü için uygulama üretilebilir.

Flutter'da arayüzün temel yapı taşı widget'tır. Stateless widget, oluşturulduktan sonra değişmeyen ve kendi durumunu tutmayan widget'tır; örneğin sabit bir başlık metni. Stateful widget ise kullanıcı etkileşimiyle değişebilen bir duruma (state) sahiptir; örneğin bir sayaç ya da onay kutusu.

Stateful widget'ın durumu değiştiğinde setState metodu çağrılır. setState, Flutter'a durumun değiştiğini bildirir ve build metodunun yeniden çalışmasını sağlayarak arayüzü günceller. initState metodu widget ilk oluşturulduğunda bir kez çalışır; dispose metodu ise widget kaldırılırken kaynakları serbest bırakmak için kullanılır.

Hot reload özelliği, kod değişikliklerinin uygulama yeniden başlatılmadan birkaç saniye içinde ekranda görülmesini sağlar. Bu özellik geliştirme sürecini önemli ölçüde hızlandırır.
"@
$m = if ($Model) { $Model } else { $null }

Write-Host "Hedef: $Base`n"
$tok = New-TestUser
$c = Test-Case "Ders ekle" "courses/create" @{ name = "Mobil Programlama" } 201 $tok
$courseId = $c.data.course.id

Write-Host "`n--- Ders notu (02-notes)"
Test-Case "Not ekle (kısa metin)"       "notes/create" @{ course_id = $courseId; title = "x"; content = "kısa" } 400 $tok | Out-Null
Test-Case "Not ekle (olmayan ders)"     "notes/create" @{ course_id = [guid]::NewGuid().ToString(); title = "x"; content = $note } 404 $tok | Out-Null
$n = Test-Case "Not ekle"               "notes/create" @{ course_id = $courseId; title = "Flutter Giriş"; content = $note; source = "txt" } 201 $tok `
        -Check { param($j) $j.data.note.id } -CheckDesc "not id'si"
$noteId = if ($n) { $n.data.note.id } else { $null }
Test-Case "Not listesi"                 "notes/list" @{ course_id = $courseId } 200 $tok `
        -Check { param($j) @($j.data.notes).Count -eq 1 -and -not $j.data.notes[0].has_summary } -CheckDesc "1 not, özetsiz" | Out-Null

Write-Host "`n--- Özet (Zorunlu 2)"
$s = Test-Case "Notu özetle"                "notes/summarize" @{ note_id = $noteId; model = $m } 200 $tok `
        -Check { param($j) $j.data.summary.short -and @($j.data.summary.key_points).Count -ge 3 -and (($j.data.summary | ConvertTo-Json -Depth 5) -notmatch $foreign) } `
        -CheckDesc "kısa özet, en az 3 madde, Türkçe"
if ($s) {
    Write-Host "       [$($s.data.model)] $($s.data.summary.short)" -ForegroundColor Cyan
    foreach ($p in $s.data.summary.key_points) { Write-Host "         - $p" -ForegroundColor Cyan }
    Write-Host "         Anahtar kavramlar: $($s.data.summary.keywords -join ', ')" -ForegroundColor Cyan
}
Test-Case "Özet (kayıtlı, model çağrılmaz)" "notes/summarize" @{ note_id = $noteId } 200 $tok `
        -Check { param($j) $j.data.cached -eq $true } -CheckDesc "cached = true" | Out-Null

Write-Host "`n--- Test oluşturma (Zorunlu 3) — 20-60 sn sürebilir"
Test-Case "Test (3 soru → geçersiz)"    "quizzes/generate" @{ note_id = $noteId; question_count = 3 } 400 $tok | Out-Null
$q = Test-Case "Test oluştur (5 soru)"   "quizzes/generate" @{ note_id = $noteId; question_count = 5; difficulty = "medium"; model = $m } 200 $tok `
        -Check { param($j) @($j.data.questions).Count -eq 5 -and -not (($j.data | ConvertTo-Json -Depth 6) -match 'correct|explanation') } `
        -CheckDesc "5 soru ve doğru cevap SIZMAMASI"
if ($q) {
    foreach ($x in $q.data.questions) {
        Write-Host "       $($x.position). [$($x.topic)] $($x.question)" -ForegroundColor Cyan
        for ($i = 0; $i -lt 4; $i++) { Write-Host "            $i) $($x.options[$i])" -ForegroundColor DarkCyan }
    }
}

Write-Host "`n--- Değerlendirme (Zorunlu 4)"
# Doğru cevapları bilmiyoruz: hepsine 0 işaretleyip sonuncuyu boş bırakıyoruz (en az bir yanlış garanti)
$answers = @()
if ($q) {
    $qs = @($q.data.questions)
    for ($i = 0; $i -lt $qs.Count; $i++) {
        $sel = if ($i -eq $qs.Count - 1) { $null } else { 0 }
        $answers += @{ question_id = $qs[$i].id; selected_index = $sel }
    }
}
$r = Test-Case "Testi teslim et"        "quizzes/submit" @{ quiz_id = $q.data.quiz_id; answers = $answers; model = $m } 200 $tok `
        -Check { param($j) @($j.data.results).Count -eq 5 -and $j.data.score -lt 5 -and $j.data.recommendation -and ($j.data.recommendation -notmatch $foreign) } `
        -CheckDesc "5 sonuç, en az 1 yanlış, Türkçe öneri"
if ($r) {
    Write-Host ("       Puan: {0}/{1} (%{2})  Zayıf konular: {3}" -f $r.data.score, $r.data.total, $r.data.percent, ($r.data.weak_topics -join ', ')) -ForegroundColor Cyan
    foreach ($x in $r.data.results) {
        $mark = if ($x.is_correct) { "DOĞRU " } else { "YANLIŞ" }
        Write-Host ("         {0}  seçilen: {1}  doğru: {2}" -f $mark, $x.selected_index, $x.correct_index) -ForegroundColor DarkCyan
    }
    Write-Host "       Öneri ($($r.data.recommendation_source)): $($r.data.recommendation)" -ForegroundColor Cyan
}
Test-Case "Aynı testi tekrar teslim (409)" "quizzes/submit" @{ quiz_id = $q.data.quiz_id; answers = $answers } 409 $tok | Out-Null

Write-Host "`n--- Ders istatistiği"
Test-Case "Ders listesi (not sayısı + ortalama)" "courses/list" @{} 200 $tok `
        -Check { param($j) $j.data.courses[0].note_count -eq 1 -and $j.data.courses[0].attempt_count -eq 1 -and $j.data.courses[0].avg_percent -ne $null } `
        -CheckDesc "1 not, 1 deneme, ortalama dolu" | Out-Null

Show-Summary "Canlı demo senaryosu"
