#requires -version 5.1
$ErrorActionPreference = 'SilentlyContinue'

$RetroBatRoot = 'C:\RetroBat'
$Work = Join-Path $RetroBatRoot 'system\gameinfo_obs'
$Overlay = Join-Path $Work 'overlay.html'
$StateFile = Join-Path $Work 'current.txt'
$GameJsFile = Join-Path $Work 'current.js'
$ConfigFile = Join-Path $Work 'config.ini'

function Get-IniValue([string]$key, [string]$default) {
    try {
        if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) { return $default }
        foreach ($line in [IO.File]::ReadAllLines($ConfigFile)) {
            $t = $line.Trim()
            if ($t -eq '' -or $t.StartsWith(';') -or $t.StartsWith('#')) { continue }
            $pos = $t.IndexOf('=')
            if ($pos -lt 1) { continue }
            if ($t.Substring(0,$pos).Trim() -ieq $key) {
                return $t.Substring($pos+1).Trim()
            }
        }
    } catch {}
    return $default
}

$RomsPath = Get-IniValue 'RomsPath' (Join-Path $RetroBatRoot 'roms')
$OverlayTitle = Get-IniValue 'Title' 'DAMBALLAHRETRO'
$OverlayWidth = [int](Get-IniValue 'Width' '720')
$OverlayHeight = [int](Get-IniValue 'Height' '250')
$ShadowEnabled=(Get-IniValue "Shadow" "false").ToLower() -eq "true"
$OverlayShadow=if($ShadowEnabled){"10px 35px rgba(0,0,0,.55)"}else{"none"}
$ScrollSpeed = [double](Get-IniValue 'ScrollSpeed' '18')
$TriggerDelaySeconds = [double](Get-IniValue 'TriggerDelaySeconds' '1')
$VisibleSeconds = [double](Get-IniValue 'VisibleSeconds' '30')
$HiddenSeconds = [double](Get-IniValue 'HiddenSeconds' '600')
$PollSeconds = [double](Get-IniValue 'PollSeconds' '1')

if ($OverlayWidth -lt 100) { $OverlayWidth = 100 }
if ($OverlayHeight -lt 80) { $OverlayHeight = 80 }
if ($ScrollSpeed -le 0) { $ScrollSpeed = 18 }
if ($TriggerDelaySeconds -lt 0) { $TriggerDelaySeconds = 0 }
if ($VisibleSeconds -lt 0) { $VisibleSeconds = 0 }
if ($HiddenSeconds -lt 0) { $HiddenSeconds = 0 }
if ($PollSeconds -lt 0.1) { $PollSeconds = 0.1 }

$Scale = [math]::Min($OverlayWidth / 720.0, $OverlayHeight / 250.0)

New-Item -ItemType Directory -Force -Path $Work | Out-Null

function Html([string]$s) {
    if ($null -eq $s) { return '' }
    return [System.Net.WebUtility]::HtmlEncode($s)
}

function Get-ImageDataUri([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return '' }
    try {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
        $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
        $mime = switch ($ext) {
            '.jpg'  { 'image/jpeg' }
            '.jpeg' { 'image/jpeg' }
            '.png'  { 'image/png' }
            '.webp' { 'image/webp' }
            '.gif'  { 'image/gif' }
            default { '' }
        }
        if ($mime -eq '') { return '' }
        $bytes = [IO.File]::ReadAllBytes($path)
        return "data:$mime;base64," + [Convert]::ToBase64String($bytes)
    } catch { return '' }
}

function Resolve-MediaPath([string]$value, [string]$systemDir) {
    if ([string]::IsNullOrWhiteSpace($value)) { return '' }
    $v = $value.Trim()
    if ($v.StartsWith('./')) { $v = $v.Substring(2) }
    $v = $v -replace '/', '\'
    if ([IO.Path]::IsPathRooted($v)) { return $v }
    return Join-Path $systemDir $v
}

function Normalize-Path([string]$p) {
    try {
        return [IO.Path]::GetFullPath($p).TrimEnd('\').ToLowerInvariant()
    } catch {
        return $p.TrimEnd('\').ToLowerInvariant()
    }
}

function Get-GameFromPath([string]$romPath) {
    if ([string]::IsNullOrWhiteSpace($romPath)) { return $null }
    $rp = Normalize-Path $romPath
    $marker = '\roms\'
    $idx = $rp.IndexOf($marker)
    if ($idx -lt 0) { return $null }

    $after = $rp.Substring($idx + $marker.Length)
    $slash = $after.IndexOf('\')
    if ($slash -lt 1) { return $null }

    $system = $after.Substring(0,$slash)
    $systemDir = Join-Path $RomsPath $system
    $gamelist = Join-Path $systemDir 'gamelist.xml'

    if (-not (Test-Path -LiteralPath $gamelist -PathType Leaf)) {
        return [pscustomobject]@{
            Name = [IO.Path]::GetFileNameWithoutExtension($romPath)
            System = $system
            Description = ''
            Image = ''
            ReleaseDate = ''
            Developer = ''
            Publisher = ''
            Genre = ''
            RomPath = $romPath
        }
    }

    try {
        # Load XML directly so its own encoding declaration is respected.
        $xml = New-Object System.Xml.XmlDocument
        $xml.Load($gamelist)
    } catch {
        return $null
    }

    $romBase = [IO.Path]::GetFileName($romPath)
    $found = $null

    foreach ($g in @($xml.gameList.game)) {
        if ($null -eq $g.path) { continue }
        $gp = [string]$g.path
        if ($gp.StartsWith('./')) { $gp = $gp.Substring(2) }
        $gp = $gp -replace '/', '\'
        $candidate = Join-Path $systemDir $gp

        if ((Normalize-Path $candidate) -eq $rp -or
            ([IO.Path]::GetFileName($candidate)).ToLowerInvariant() -eq $romBase.ToLowerInvariant()) {
            $found = $g
            break
        }
    }

    if ($null -eq $found) {
        $name = [IO.Path]::GetFileNameWithoutExtension($romPath)
        return [pscustomobject]@{
            Name = $name
            System = $system
            Description = ''
            Image = ''
            ReleaseDate = ''
            Developer = ''
            Publisher = ''
            Genre = ''
            RomPath = $romPath
        }
    }

    $release = [string]$found.releasedate
    if ($release.Length -ge 4) { $release = $release.Substring(0,4) }

    $img = Resolve-MediaPath ([string]$found.image) $systemDir

    [pscustomobject]@{
        Name = [string]$found.name
        System = $system
        Description = [string]$found.desc
        Image = $img
        ReleaseDate = $release
        Developer = [string]$found.developer
        Publisher = [string]$found.publisher
        Genre = [string]$found.genre
        RomPath = $romPath
    }
}

function Find-RunningRom {
    $excluded = @(
        'RetroBat.exe','EmulationStation.exe','emulationstation.exe',
        'BatGui.exe','explorer.exe','obs64.exe','powershell.exe',
        'cmd.exe','conhost.exe','GameInfo.ps1'
    )

    $marker = ($RomsPath.TrimEnd('\') + '\')

    try {
        $procs = Get-CimInstance Win32_Process | Where-Object {
            $_.CommandLine -and
            $_.CommandLine.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            ($excluded -notcontains $_.Name)
        }

        $candidates = @()

        foreach ($p in $procs) {
            $cmd = [string]$p.CommandLine

            $m = [regex]::Match($cmd, '(?i)"(' + [regex]::Escape($marker) + '[^"]+)"')
            if (-not $m.Success) {
                $m = [regex]::Match($cmd, '(?i)(' + [regex]::Escape($marker) + '[^\s"]+)')
            }

            if ($m.Success) {
                $path = $m.Groups[1].Value
                $path = $path.TrimEnd('"')
                if (Test-Path -LiteralPath $path -PathType Leaf) {
                    $candidates += [pscustomobject]@{
                        Path = $path
                        ProcessId = $p.ProcessId
                        Name = $p.Name
                    }
                }
            }
        }

        if ($candidates.Count -gt 0) {
            return $candidates[0]
        }
    } catch {}

    return $null
}

function Clear-Overlay {
    $html = @"
<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0;background:transparent;width:100%;height:100%;overflow:hidden}
</style></head><body></body></html>
"@
    try {
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($Overlay, $html, $utf8)
        [IO.File]::WriteAllText($GameJsFile, 'window.__DAMB_GAME=null; window.__DAMB_GAME_VERSION=' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + ';', $utf8)
        if (Test-Path -LiteralPath $StateFile) { Remove-Item -LiteralPath $StateFile -Force }
    } catch {}
}

function Write-Overlay($game) {
    $name = Html $game.Name
    $system = Html $game.System
    $desc = Html $game.Description
    $year = Html $game.ReleaseDate
    $dev = Html $game.Developer
    $pub = Html $game.Publisher
    $genre = Html $game.Genre
    $img = Get-ImageDataUri $game.Image

    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Jeu retro' }

    $meta = @()
    if ($system) { $meta += $system }
    if ($year) { $meta += $year }
    if ($genre) { $meta += $genre }
    $metaLine = ($meta -join '  &#8226;  ')

    $company = ''
    if ($dev -and $pub -and $dev -ne $pub) { $company = "$dev &#8226; $pub" }
    elseif ($dev) { $company = $dev }
    elseif ($pub) { $company = $pub }

    $imageHtml = ''
    if ($img) {
        $imageHtml = "<div class='cover'><img src='$img' alt=''></div>"
    } else {
        $imageHtml = "<div class='cover no-cover'><div>NO<br>IMAGE</div></div>"
    }

    $companyHtml = ''
    if ($company) { $companyHtml = "<div class='company'>$company</div>" }

    # The generated HTML is UTF-8. It also reloads itself every 2 seconds,
    # which lets an OBS Browser Source using the local file see new games.
    $html = @"
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<style>
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:transparent;font-family:Arial,Helvetica,sans-serif;color:#fff}
 .card{
 --scale:${Scale};
 width:${OverlayWidth}px;
 height:${OverlayHeight}px;
 padding:calc(34px * var(--scale)) calc(22px * var(--scale)) calc(22px * var(--scale)) calc(22px * var(--scale));
 display:flex;
 gap:calc(22px * var(--scale));
 align-items:center;
 position:relative;
 overflow:hidden;
 background:linear-gradient(135deg,rgba(8,8,14,.96),rgba(25,18,40,.94));
 border:2px solid rgba(255,255,255,.35);
 border-radius:18px;
 box-shadow:${OverlayShadow};
 opacity:0;
 transition:opacity 2s ease-in-out;
}
.card.ready{opacity:1;}
.cover{
 width:calc(155px * var(--scale));
 height:calc(205px * var(--scale));
 flex:0 0 calc(155px * var(--scale));
 display:flex;
 align-items:center;
 justify-content:center;
 overflow:hidden;
 border-radius:10px;
 background:#111;
 box-shadow:0 4px 18px rgba(0,0,0,.55);
}
.cover img{width:100%;height:100%;object-fit:contain}
.no-cover{color:#777;text-align:center;font-size:calc(18px * var(--scale));font-weight:bold}
.info{min-width:0;min-height:0;flex:1;overflow:hidden}
.kicker{font-size:calc(13px * var(--scale));letter-spacing:calc(3px * var(--scale));text-transform:uppercase;opacity:.65;margin-bottom:calc(6px * var(--scale));white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.title{font-size:calc(32px * var(--scale));font-weight:900;line-height:1.05;text-transform:uppercase;margin-bottom:calc(10px * var(--scale));text-shadow:2px 2px 0 #000;max-height:calc(67px * var(--scale));overflow:hidden}
.meta{font-size:calc(15px * var(--scale));opacity:.8;margin-bottom:calc(10px * var(--scale));white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.company{font-size:calc(13px * var(--scale));opacity:.62;margin-bottom:calc(10px * var(--scale));white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.desc-viewport{height:calc(100px * var(--scale));overflow:hidden;position:relative}
.desc-track{font-size:calc(15px * var(--scale));line-height:1.35;color:#eee;will-change:transform}
.desc-text{display:block}
.desc-gap{height:calc(28px * var(--scale))}

@media (max-width:500px),(max-height:180px){
 .card{padding:8px;gap:8px;border-radius:12px}
 .cover{width:74px;height:94px;flex-basis:74px;border-radius:7px}
 .kicker{font-size:9px;letter-spacing:1px;margin-bottom:3px}
 .title{font-size:18px;line-height:1;max-height:37px;margin-bottom:4px}
 .meta{font-size:9px;margin-bottom:3px}
 .company{font-size:9px;margin-bottom:3px}
 .desc-viewport{height:calc(100% - 75px);min-height:18px}
 .desc-track{font-size:9px;line-height:1.25}
 .desc-gap{height:10px}
}
@media (max-width:380px),(max-height:140px){
 .card{padding:5px;gap:6px;border-width:1px;border-radius:9px}
 .cover{width:58px;height:74px;flex-basis:58px}
 .kicker{font-size:7px;letter-spacing:.7px;margin-bottom:2px}
 .title{font-size:14px;max-height:29px;margin-bottom:2px}
 .meta,.company{font-size:7px;margin-bottom:2px}
 .desc-viewport{height:calc(100% - 57px)}
 .desc-track{font-size:7px;line-height:1.2}
 .desc-gap{height:7px}
}
</style>
</head>
<body data-start-ms="$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())">
<div class="card">
$imageHtml
<div class="info">
<div class="kicker">$([System.Net.WebUtility]::HtmlEncode($OverlayTitle)) &#8226; EN COURS</div>
<div class="title">$name</div>
<div class="meta">$metaLine</div>
$companyHtml
<div class="desc-viewport">
  <div class="desc-track" id="descTrack">
    <div class="desc-text" id="descText">$desc</div>
    <div class="desc-gap"></div>
    <div class="desc-text" id="descText2">$desc</div>
  </div>
</div>
</div>
</div>
<script>
(function(){
  var visibleMs=${VisibleSeconds}*1000, hiddenMs=${HiddenSeconds}*1000, cycle=visibleMs+hiddenMs;
  var lastVersion="", gameStart=0, lastGameKey="";

  function setVisible(on){
    var card=document.querySelector('.card');
    if(card) card.classList.toggle('ready',!!on);
  }

  function startScroll(){
    var viewport=document.querySelector('.desc-viewport');
    var track=document.getElementById('descTrack');
    var first=document.getElementById('descText');
    if(!viewport||!track||!first)return;
    track.style.animation='none';
    track.offsetHeight;
    var gap=parseFloat(getComputedStyle(document.querySelector('.desc-gap')).height)||0; var distance=first.offsetHeight+gap;
    if(distance>viewport.clientHeight){
      var duration=Math.max(12,distance/${ScrollSpeed});
      track.style.setProperty('--scroll-distance',distance+'px');
      track.style.animation='dambScroll '+duration+'s linear infinite';
    } else {
      track.style.transform='translateY(0)';
    }
  }

  function applyGame(data){
    if(!data || !data.name){
      setVisible(false);
      lastGameKey="";
      return;
    }

    var key=(data.name||"")+"|"+(data.system||"")+"|"+(data.image||"");
    if(key!==lastGameKey){
      lastGameKey=key;
      gameStart=parseInt(data.changedMs||Date.now(),10);
      var title=document.querySelector('.title');
      var meta=document.querySelector('.meta');
      var company=document.querySelector('.company');
      var desc=document.getElementById('descText');
      var desc2=document.getElementById('descText2');
      var cover=document.querySelector('.cover img');

      if(title)title.textContent=data.name||"";
      if(meta)meta.textContent=[data.system,data.year,data.genre].filter(Boolean).join("  •  ");
      if(company)company.textContent=data.developer||data.publisher||"";
      if(desc)desc.textContent=data.description||"";
      if(desc2)desc2.textContent=data.description||"";
      if(cover&&data.image)cover.src=data.image;

      startScroll();
    }

    var elapsed=Date.now()-gameStart;
    var phase=((elapsed%cycle)+cycle)%cycle;
    setVisible(phase<visibleMs);
  }

  function loadState(){
    var s=document.createElement('script');
    s.src='current.js?t='+Date.now();
    s.onload=function(){
      var data=window.__DAMB_GAME||null;
      var version=String(window.__DAMB_GAME_VERSION||"");
      if(version!==lastVersion){
        lastVersion=version;
        applyGame(data);
      } else {
        applyGame(data);
      }
      if(s.parentNode)s.parentNode.removeChild(s);
    };
    s.onerror=function(){if(s.parentNode)s.parentNode.removeChild(s);};
    document.head.appendChild(s);
  }

  setInterval(loadState,1000);
  loadState();
  setTimeout(startScroll,200);
})();
</script>
<style>
@keyframes dambScroll{
  from{transform:translateY(0)}
  to{transform:translateY(calc(-1 * var(--scroll-distance)))}
}
</style>
</body>
</html>
"@

    try {
        # UTF-8 WITHOUT BOM is ideal for HTML in OBS/Chromium.
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($Overlay, $html, $utf8)
        [IO.File]::WriteAllText($StateFile, ($game.RomPath + "`n" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()), $utf8)

        $state = [ordered]@{
            name = $game.Name
            system = $game.System
            year = $game.ReleaseDate
            genre = $game.Genre
            developer = $game.Developer
            publisher = $game.Publisher
            description = $game.Description
            image = $img
            changedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        }
        $stateJson = $state | ConvertTo-Json -Compress -Depth 5
        $stateJs = 'window.__DAMB_GAME=' + $stateJson + '; window.__DAMB_GAME_VERSION=' + $state.changedMs + ';'
        [IO.File]::WriteAllText($GameJsFile, $stateJs, $utf8)
    } catch {
        # Fallback for unusual file locking situations.
        try {
            [IO.File]::WriteAllText($Overlay, $html)
            [IO.File]::WriteAllText($StateFile, $game.RomPath)
            $stateJson = $state | ConvertTo-Json -Compress -Depth 5
            [IO.File]::WriteAllText($GameJsFile, ('window.__DAMB_GAME=' + $stateJson + ';'), (New-Object System.Text.UTF8Encoding($false)))
        } catch {}
    }
}

Write-Host ''
Write-Host 'Surveillance active. Lancez un jeu depuis RetroBat.'
Write-Host ''

$lastRom = ''

while ($true) {
    $running = Find-RunningRom

    if ($null -ne $running) {
        $rom = Normalize-Path $running.Path

        if ($rom -ne $lastRom) {
            $game = Get-GameFromPath $running.Path

            if ($null -ne $game) {
                if ($TriggerDelaySeconds -gt 0) {
                    Start-Sleep -Milliseconds ([int]($TriggerDelaySeconds * 1000))
                    $check = Find-RunningRom
                    if ($null -eq $check -or (Normalize-Path $check.Path) -ne $rom) {
                        $lastRom = ''
                        continue
                    }
                }
                Write-Overlay $game
                $lastRom = $rom
                Write-Host ('Jeu detecte : ' + $game.Name + ' [' + $game.System + ']')
            }
        }
    } else {
        if ($lastRom -ne '') {
            Clear-Overlay
        }
        $lastRom = ''
    }

    Start-Sleep -Milliseconds ([int]($PollSeconds * 1000))
}
