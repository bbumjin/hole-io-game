# PLAN.md 의 "전문" 코드 블록을 실제 파일과 대조한다(-Check) / 실제 파일로 맞춘다(-Fix).
#
# PLAN.md 는 여러 소스의 **전문**을 싣고 "이 문서의 모든 코드 블록은 그 파일들과
# 바이트 단위로 동일하다" 고 단언한다. 그 단언은 손으로 지켜지지 않았다 —
# §24 시점에 아홉 블록 중 일곱이 어긋나 있었다(screenshot.gd 는 502줄 차이).
# 사람이 지키는 규율은 이렇게 조용히 깨지므로 기계가 확인하게 한다.
#
#   pwsh tools/sync_plan_blocks.ps1            # 대조만 (어긋나면 exit 1)
#   pwsh tools/sync_plan_blocks.ps1 -Fix       # 문서를 파일에 맞춘다
param([switch]$Fix)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$planPath = Join-Path $root 'PLAN.md'
$plan = [System.IO.File]::ReadAllLines($planPath)

# "전문" 이라고 적힌 헤더에서 파일 경로를 뽑고, 바로 뒤 코드펜스의 내용을 그 파일과 견준다.
$blocks = @()
for ($i = 0; $i -lt $plan.Count; $i++) {
	# 헤더가 `### ...` 인 자리도 있고 백틱 경로만 한 줄로 놓인 자리도 있다(camera_rig).
	if ($plan[$i] -notmatch '전문') { continue }
	if ($plan[$i] -notmatch '`([A-Za-z0-9_./]+\.(gd|tscn|gdshader|godot))`') { continue }
	$rel = $Matches[1]
	$s = -1
	for ($j = $i + 1; $j -lt [Math]::Min($i + 8, $plan.Count); $j++) {
		if ($plan[$j] -match '^```') { $s = $j; break }
	}
	if ($s -lt 0) { continue }
	$e = -1
	for ($j = $s + 1; $j -lt $plan.Count; $j++) {
		if ($plan[$j] -eq '```') { $e = $j; break }
	}
	if ($e -lt 0) { continue }
	# 헤더가 `main.gd` 처럼 짧게 적힌 자리가 있다. 루트에 없으면 scripts/ 에서 찾는다.
	$full = Join-Path $root $rel
	if (-not (Test-Path $full)) { $full = Join-Path $root (Join-Path 'scripts' $rel) }
	if (-not (Test-Path $full)) { throw "블록의 대상 파일을 찾지 못했다: $rel (PLAN.md:$($i + 1))" }
	$blocks += [pscustomobject]@{ rel = $rel; path = $full; open = $s; close = $e }
}

$bad = 0
foreach ($b in $blocks) {
	$embedded = ($plan[($b.open + 1)..($b.close - 1)] -join "`n").TrimEnd()
	$actual = ([System.IO.File]::ReadAllLines($b.path) -join "`n").TrimEnd()
	if ($embedded -eq $actual) {
		Write-Output ("MATCH  {0}" -f $b.rel)
	} else {
		$bad++
		Write-Output ("DIFF   {0}  (문서 {1}줄 / 파일 {2}줄)" -f $b.rel,
			($b.close - $b.open - 1), ([System.IO.File]::ReadAllLines($b.path)).Count)
	}
}

if (-not $Fix) {
	Write-Output ("어긋난 블록 {0}개 / 전체 {1}개" -f $bad, $blocks.Count)
	exit ($(if ($bad -gt 0) { 1 } else { 0 }))
}

# 아래에서 위로 갈아 끼운다 — 위에서부터 하면 뒤 블록의 줄 번호가 밀린다.
$out = [System.Collections.Generic.List[string]]::new()
$out.AddRange([string[]]$plan)
foreach ($b in ($blocks | Sort-Object open -Descending)) {
	$body = [System.IO.File]::ReadAllLines($b.path)
	while ($body.Count -gt 0 -and $body[-1] -eq '') { $body = $body[0..($body.Count - 2)] }
	$out.RemoveRange($b.open + 1, $b.close - $b.open - 1)
	$out.InsertRange($b.open + 1, [string[]]$body)
}
[System.IO.File]::WriteAllLines($planPath, $out, [System.Text.UTF8Encoding]::new($false))
Write-Output ("PLAN.md 의 블록 {0}개를 파일에 맞췄다." -f $blocks.Count)
