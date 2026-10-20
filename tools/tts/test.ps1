param(
    [string]$TtsManagedPath = $env:TTS_MANAGED_DIR
)
$ErrorActionPreference = 'Stop'
if (-not $TtsManagedPath) {
    $TtsManagedPath = Join-Path ${env:ProgramFiles(x86)} 'Steam/steamapps/common/Tabletop Simulator/Tabletop Simulator_Data/Managed'
}
$moonSharp = Join-Path $TtsManagedPath 'MoonSharp.Interpreter.dll'
if (-not (Test-Path -LiteralPath $moonSharp)) {
    throw 'MoonSharp.Interpreter.dll not found. Install Tabletop Simulator and pass -TtsManagedPath (or TTS_MANAGED_DIR). Do not copy game DLLs into this repository.'
}
Add-Type -LiteralPath $moonSharp
$repositoryDirectory = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptDirectory = Join-Path $repositoryDirectory 'tts'
$harness = [System.IO.File]::ReadAllText((Join-Path $repositoryDirectory 'tests/tts/behavior.lua'))
function Assert-XmlNumber($actual, $expected, $message) {
    $number = [double]::Parse([string]$actual, [System.Globalization.CultureInfo]::InvariantCulture)
    if ([Math]::Abs($number - $expected) -gt 0.00001) { throw ($message + ': expected ' + $expected + ', got ' + $actual) }
}
function Assert-XmlOffset($element, $x, $y) {
    $parts = $element.GetAttribute('offsetXY').Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($parts.Count -ne 2) { throw ('Invalid offsetXY: ' + $element.id) }
    Assert-XmlNumber $parts[0] $x ('Horizontal position: ' + $element.id)
    Assert-XmlNumber $parts[1] $y ('Vertical position: ' + $element.id)
}
foreach ($panelFile in @('modules/commanders.lua', 'Global.lua')) {
    $source = [System.IO.File]::ReadAllText((Join-Path $scriptDirectory $panelFile))
    $runtime = [MoonSharp.Interpreter.Script]::new()
    $null = $runtime.DoString($harness)
    $null = $runtime.DoString($source)
    $merged = if (($panelFile -eq 'Global.lua')) { 'true' } else { 'false' }
    $null = $runtime.DoString('initTeamPanel()')
    # 检查实际生成的十二份座席 UI，而非仅检查 XML 模板。
    [xml]$xmlDocument = '<Root>' + $runtime.DoString('return UI.xml').String + '</Root>'
    $ids = @{}
    foreach ($element in $xmlDocument.SelectNodes('//*[@id]')) {
        if ($ids.ContainsKey($element.id)) { throw ('Duplicate XML id: ' + $element.id) }
        $ids[$element.id] = $true
    }
    foreach ($seatColor in @('White','Brown','Red','Orange','Yellow','Green','Teal','Blue','Purple','Pink','Grey','Black')) {
    $panelID = 'sg_' + $seatColor + '_panel'
    $panelElement = $xmlDocument.SelectSingleNode("//*[@id='$panelID']")
    if ($panelElement.visibility -ne $seatColor) { throw ('Incorrect seat visibility: ' + $panelID) }
    $mainPrefix = 'sg_' + $seatColor + '_main'
    $mainCard = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_card']")
    $visualGroup = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_visual_group']")
    $flag = $xmlDocument.SelectSingleNode("//*[@id='sg_${seatColor}_flag']")
    if (-not $visualGroup -or $visualGroup.Name -ne 'Panel' -or $visualGroup.color -ne '#FFFFFF00' -or $visualGroup.raycastTarget -ne 'false') {
        throw ('Portrait visual group must be a transparent Panel: ' + $mainPrefix)
    }
    if ($visualGroup.ParentNode -ne $mainCard -or $visualGroup.rectAlignment -ne 'UpperCenter') { throw ('Portrait visual group must stay inside main card: ' + $mainPrefix) }
    Assert-XmlOffset $visualGroup 0 -37
    Assert-XmlNumber $visualGroup.width 266 ('Portrait visual group width: ' + $visualGroup.id)
    Assert-XmlNumber $visualGroup.height 266 ('Portrait visual group height: ' + $visualGroup.id)
    $mainRole = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_role']")
    Assert-XmlOffset $mainRole 0 -8
    Assert-XmlNumber $mainRole.width 266 ('Main title width matches portrait group: ' + $mainRole.id)
    Assert-XmlNumber $mainRole.height 24 ('Main title height: ' + $mainRole.id)
    if (-not $flag -or $flag.Name -ne 'Image' -or $flag.ParentNode -ne $mainCard -or $flag.rectAlignment -ne 'UpperCenter') {
        throw ('Flag must be an independent Image within main card: ' + $mainPrefix)
    }
    if ($flag.preserveAspect -ne 'true' -or $flag.raycastTarget -ne 'false' -or $flag.color -ne '#FFFFFF' -or $flag.active -ne 'false' -or $flag.GetAttribute('tooltip') -ne '') {
        throw ('Flag must preserve proportions, colors and click-through behavior: ' + $flag.id)
    }
    Assert-XmlOffset $flag 140 -50
    Assert-XmlNumber $flag.width 90 ('Flag width: ' + $flag.id)
    Assert-XmlNumber $flag.height 240 ('Flag height: ' + $flag.id)
    foreach ($visualPart in @('portrait_frame','portrait','no_image','acted_stamp','acted_fallback','injury_badge')) {
        $visualElement = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_$visualPart']")
        if ($visualElement.ParentNode -ne $visualGroup) { throw ('Portrait layer must move with visual group: ' + $visualElement.id) }
    }
    $mainFrame = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_portrait_frame']")
    Assert-XmlOffset $mainFrame 0 0
    Assert-XmlNumber $mainFrame.width 266 ('Main frame width: ' + $mainFrame.id)
    Assert-XmlNumber $mainFrame.height 266 ('Main frame height: ' + $mainFrame.id)
    $mainPortrait = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_portrait']")
    $mainPlaceholder = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_no_image']")
    $mainBackgrounds = @($visualGroup.SelectNodes('./Panel[not(@id)]'))
    if ($mainBackgrounds.Count -ne 1) { throw ('Main visual group must contain portrait background: ' + $visualGroup.id) }
    foreach ($portraitLayer in @($mainPortrait, $mainPlaceholder, $mainBackgrounds[0])) {
        Assert-XmlOffset $portraitLayer 0 -3
        Assert-XmlNumber $portraitLayer.width 260 ('Main portrait layer width: ' + $portraitLayer.id)
        Assert-XmlNumber $portraitLayer.height 260 ('Main portrait layer height: ' + $portraitLayer.id)
    }
    foreach ($visualPart in @('acted_stamp','acted_fallback')) {
        $stampLayer = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_$visualPart']")
        Assert-XmlOffset $stampLayer 70 -147
        Assert-XmlNumber $stampLayer.width 112 ('Main stamp layer width: ' + $stampLayer.id)
        Assert-XmlNumber $stampLayer.height 112 ('Main stamp layer height: ' + $stampLayer.id)
    }
    $mainBadge = $xmlDocument.SelectSingleNode("//*[@id='${mainPrefix}_injury_badge']")
    Assert-XmlOffset $mainBadge -86 -9
    Assert-XmlNumber $mainBadge.width 72 ('Main injury badge width: ' + $mainBadge.id)
    Assert-XmlNumber $mainBadge.height 28 ('Main injury badge height: ' + $mainBadge.id)
    # 有旗时按实际画像边缘计算组合中线，框的额外 3 像素不参与。
    $flagOffset = $flag.GetAttribute('offsetXY').Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
    $flagX = [double]$flagOffset[0]
    $flagTop = -[double]$flagOffset[1]
    Assert-XmlNumber ($flagX - [double]$flag.width / 2 - (-55 + [double]$mainPortrait.width / 2)) 20 ('Portrait and flag gap: ' + $mainPrefix)
    Assert-XmlNumber ((-55 - [double]$mainPortrait.width / 2 + $flagX + [double]$flag.width / 2) / 2) 0 ('Portrait and flag centered bounds: ' + $mainPrefix)
    Assert-XmlNumber (37 + 3 + [double]$mainPortrait.height / 2) ($flagTop + [double]$flag.height / 2) ('Portrait and flag vertical centers: ' + $mainPrefix)
    # 最下排新增本隊陣旗后六按钮必须仍可点击且不重叠、不越界。
    $bottomNames = @('mapflags','pin','refresh','smaller','larger','close')
    $bottomCallbacks = @('sgToggleMapFlags','sgPin','sgRefresh','sgResize','sgResize','sgClose')
    $previousRight = -[double]$panelElement.width / 2
    for ($buttonIndex = 0; $buttonIndex -lt $bottomNames.Count; $buttonIndex++) {
        $buttonID = 'sg_' + $seatColor + '_' + $bottomNames[$buttonIndex]
        $button = $xmlDocument.SelectSingleNode("//*[@id='$buttonID']")
        if (-not $button -or $button.Name -ne 'Button' -or $button.ParentNode -ne $panelElement -or $button.rectAlignment -ne 'UpperCenter') {
            throw ('Bottom control must be a direct centered Button: ' + $buttonID)
        }
        if ($button.onClick -ne $bottomCallbacks[$buttonIndex] -or $button.raycastTarget -eq 'false') {
            throw ('Bottom control must retain correct clickable callback: ' + $buttonID)
        }
        $buttonOffset = $button.GetAttribute('offsetXY').Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        $buttonX = [double]$buttonOffset[0]
        $buttonTop = -[double]$buttonOffset[1]
        $buttonLeft = $buttonX - [double]$button.width / 2
        $buttonRight = $buttonX + [double]$button.width / 2
        if ($buttonLeft -lt $previousRight -or $buttonRight -gt [double]$panelElement.width / 2 -or $buttonTop -lt 0 -or $buttonTop + [double]$button.height -gt [double]$panelElement.height) {
            throw ('Bottom control overlaps or exceeds panel bounds: ' + $buttonID)
        }
        Assert-XmlNumber $buttonTop 952 ('Bottom control shared row: ' + $buttonID)
        Assert-XmlNumber $button.height 30 ('Bottom control height: ' + $buttonID)
        $previousRight = $buttonRight
    }
    foreach ($person in @('main', 'deputy1', 'deputy2')) {
        foreach ($part in @('role','name','command_row','command_label','command_box','command','command_bar','command_slot1','command_slot2','command_slot3','command_slot4','command_slot5','command_slot6','mobility','status_label','status','status_text','action','portrait','no_image','portrait_frame','acted_stamp','acted_fallback','injury_badge','injury_label')) {
            $expectedID = 'sg_' + $seatColor + '_' + $person + '_' + $part
            if (-not $ids.ContainsKey($expectedID)) { throw ('Missing UI target: ' + $expectedID) }
        }
        $statusID = 'sg_' + $seatColor + '_' + $person + '_status'
        $statusButton = $xmlDocument.SelectSingleNode("//*[@id='$statusID']")
        if ($statusButton.Name -ne 'Button' -or $statusButton.onClick -ne 'sgSetStatus') {
            throw ('Status element must be a Button bound to sgSetStatus: ' + $statusID)
        }
        if ($statusButton.raycastTarget -ne 'true') { throw ('Status button must accept clicks: ' + $statusID) }
        if ($statusButton.text -ne '' -or $statusButton.InnerText -ne '') { throw ('Status button must have no internal label: ' + $statusID) }
        $statusLabel = $xmlDocument.SelectSingleNode("//*[@id='${statusID}_label']")
        $statusText = $xmlDocument.SelectSingleNode("//*[@id='${statusID}_text']")
        if ($statusLabel.Name -ne 'Text' -or $statusLabel.InnerText -ne '状態' -or $statusLabel.HasAttribute('colors')) {
            throw ('Fixed state label must be plain Text: ' + $statusID)
        }
        if ($statusLabel.raycastTarget -ne 'false' -or $statusText.raycastTarget -ne 'false') {
            throw ('State Text elements must not intercept clicks: ' + $statusID)
        }
        foreach ($geometry in @('rectAlignment','offsetXY','width','height')) {
            if ($statusText.GetAttribute($geometry) -ne $statusButton.GetAttribute($geometry)) {
                throw ('State overlay differs from button bounds: ' + $statusID)
            }
        }
        if ($statusButton.NextSibling -ne $statusText) { throw ('State overlay must follow button in draw order: ' + $statusID) }
        foreach ($statusElement in @($statusButton, $statusLabel, $statusText)) {
            if ($statusElement.GetAttribute('tooltip') -ne '') { throw ('State tooltip must be absent: ' + $statusElement.id) }
        }
        $barID = 'sg_' + $seatColor + '_' + $person + '_command_bar'
        $bar = $xmlDocument.SelectSingleNode("//*[@id='$barID']")
        if ($bar.Name -ne 'Panel' -or $bar.color -ne '#FFFFFF00' -or $bar.raycastTarget -ne 'false') {
            throw ('Command bar must be a transparent Panel: ' + $barID)
        }
        if ($bar.HasAttribute('fontSize') -or $bar.HasAttribute('text')) { throw ('Command bar Panel must not carry text: ' + $barID) }
        $minimumDotSize = if ($person -eq 'main') { 30 } else { 24 }
        $slotWidth = if ($person -eq 'main') { 28 } else { 24 }
        $slotHeight = if ($person -eq 'main') { 36 } else { 34 }
        $rise = if ($person -eq 'main') { 2 } else { 1 }
        $rowWidth = if ($person -eq 'main') { 276 } else { 235 }
        $rowHeight = if ($person -eq 'main') { 40 } else { 38 }
        $rowY = if ($person -eq 'main') { -353 } else { -281 }
        $labelX = if ($person -eq 'main') { -118 } else { -96.5 }
        $labelWidth = if ($person -eq 'main') { 40 } else { 42 }
        $numberX = if ($person -eq 'main') { -67 } else { -53.5 }
        $numberWidth = if ($person -eq 'main') { 38 } else { 30 }
        $barX = if ($person -eq 'main') { 54 } else { 45.5 }
        $prefix = 'sg_' + $seatColor + '_' + $person
        $row = $xmlDocument.SelectSingleNode("//*[@id='${prefix}_command_row']")
        $label = $xmlDocument.SelectSingleNode("//*[@id='${prefix}_command_label']")
        $box = $xmlDocument.SelectSingleNode("//*[@id='${prefix}_command_box']")
        $number = $xmlDocument.SelectSingleNode("//*[@id='${prefix}_command']")
        if ($row.Name -ne 'Panel' -or $row.color -ne '#FFFFFF00' -or $row.rectAlignment -ne 'UpperCenter') {
            throw ('Command row must be a centered transparent Panel: ' + $row.id)
        }
        Assert-XmlOffset $row 0 $rowY
        Assert-XmlNumber $row.width $rowWidth ('Command row width: ' + $row.id)
        Assert-XmlNumber $row.height $rowHeight ('Command row height: ' + $row.id)
        foreach ($member in @($label, $box, $number, $bar)) {
            if ($member.ParentNode -ne $row -or $member.rectAlignment -ne 'MiddleCenter') {
                throw ('Command row member must use its shared center: ' + $member.id)
            }
        }
        Assert-XmlOffset $label $labelX 0
        Assert-XmlNumber $label.width $labelWidth ('Command label width: ' + $label.id)
        Assert-XmlNumber $label.height $slotHeight ('Command label height: ' + $label.id)
        foreach ($member in @($box, $number)) {
            Assert-XmlOffset $member $numberX 0
            Assert-XmlNumber $member.width $numberWidth ('Command number width: ' + $member.id)
            Assert-XmlNumber $member.height $slotHeight ('Command number height: ' + $member.id)
        }
        Assert-XmlOffset $bar $barX 0
        Assert-XmlNumber $bar.width ($slotWidth * 6) ('Command bar width: ' + $bar.id)
        Assert-XmlNumber $bar.height $rowHeight ('Command bar height: ' + $bar.id)
        Assert-XmlNumber ($labelX - $labelWidth / 2) (-$rowWidth / 2) ('Symmetric row left bound: ' + $row.id)
        Assert-XmlNumber ($barX + $slotWidth * 3) ($rowWidth / 2) ('Symmetric row right bound: ' + $row.id)
        $slots = @($bar.SelectNodes('./Text'))
        if ($slots.Count -ne 6 -or $bar.ChildNodes.Count -ne 6) { throw ('Command bar must contain exactly six Text slots: ' + $bar.id) }
        for ($slotIndex = 1; $slotIndex -le 6; $slotIndex++) {
            $slot = $xmlDocument.SelectSingleNode("//*[@id='${prefix}_command_slot$slotIndex']")
            if ($slot.ParentNode -ne $bar -or $slot.Name -ne 'Text' -or $slot.rectAlignment -ne 'MiddleCenter' -or $slot.alignment -ne 'MiddleCenter') {
                throw ('Command slot must be centered Text inside its bar: ' + $slot.id)
            }
            if ($slot.raycastTarget -ne 'false' -or $slot.InnerText -ne '○') { throw ('Invalid initial command slot: ' + $slot.id) }
            if ([int]$slot.fontSize -lt $minimumDotSize -or $slot.resizeTextForBestFit -eq 'true') {
                throw ('Command slot must keep enlarged circle font size: ' + $slot.id)
            }
            Assert-XmlOffset $slot ($slotWidth * ($slotIndex - 3.5)) $rise
            Assert-XmlNumber $slot.width $slotWidth ('Command slot width: ' + $slot.id)
            Assert-XmlNumber $slot.height $slotHeight ('Command slot height: ' + $slot.id)
            if ($rise + $slotHeight / 2 -gt $rowHeight / 2) { throw ('Command optical rise exceeds row bounds: ' + $slot.id) }
        }
    }
    }
    foreach ($element in $xmlDocument.SelectNodes('//*[@onClick]')) {
        $callbackName = $element.onClick
        if ($runtime.Globals.Get($callbackName).Type -ne [MoonSharp.Interpreter.DataType]::Function) {
            throw ('Missing Lua callback for XML button: ' + $callbackName)
        }
    }
    foreach ($element in $xmlDocument.SelectNodes('//Text|//Button')) {
        $visibleText = $element.InnerText + $element.GetAttribute('text') + $element.GetAttribute('tooltip')
        if ($visibleText -match '[\u3040-\u309F\u30A1-\u30FA\uFF66-\uFF9D]') { throw ('Visible UI text contains kana: ' + $element.id) }
    }
    if ($xmlDocument.SelectSingleNode("//*[@id='sg_White_formation']").InnerText -ne '請指向武將令牌') { throw 'Initial prompt must use Chinese' }
    if ($xmlDocument.SelectSingleNode("//*[@id='sg_White_close']").InnerText -ne '關閉') { throw 'Close button must use traditional Chinese' }
    foreach ($eventName in @('onLoad','onObjectSpawn','onObjectDestroy','onObjectHover','onObjectRotate','onObjectDrop','onObjectEnterContainer','onObjectLeaveContainer','onObjectStateChange','onPlayerChangeColor','onPlayerDisconnect')) {
        if ([regex]::Matches($source, "function $eventName\(").Count -ne 1) { throw "Duplicate event: $eventName" }
    }
    try {
        $runtime.DoString('return runTeamChecks(' + $merged + ')').ToPrintString()
    } catch {
        if ($_.Exception.InnerException.DecoratedMessage) { Write-Output $_.Exception.InnerException.DecoratedMessage }
        throw
    }
    Write-Output ($panelFile + ': XML buttons, callbacks, IDs and event entry points passed')
}
