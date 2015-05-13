Func AutoSnipe(ByRef $timer, ByRef $THLocation, ByRef $THLeft, ByRef $THTop)
   ;DebugWrite("AutoSnipe()")

   Switch $gAutoStage

   ; Stage Queue Training
   Case $eAutoQueueTraining
	  GUICtrlSetData($GUI_AutoStatus, "Auto: Queue Training")

	  ResetToCoCMainScreen()

	  AutoQueueTroops()
	  $timer = TimerInit()

   ; Stage Wait For Training To Complete
   Case $eAutoWaitForTrainingToComplete

	  If TimerDiff($timer) >= $gTroopTrainingCheckInterval Then
		 ResetToCoCMainScreen()
		 AutoCheckIfTroopsReady()
		 $timer = TimerInit()
	  EndIf

   ; Stage Find Match
   Case $eAutoFindMatch
	  GUICtrlSetData($GUI_AutoStatus, "Auto: Find Snipable TH")

	  Local $zappable
	  Local $findMatchResults = AutoSnipeFindMatch($THLocation, $THLeft, $THTop, $zappable)

	  If $zappable Then
		 GUICtrlSetData($GUI_AutoStatus, "Auto: Execute DE Zap")
		 AutoDEZap()
		 GUICtrlSetData($GUI_AutoStatus, "Auto: DE Zap Complete")
	  EndIf

	  If $findMatchResults = $eAutoExecute Then
		 $gAutoStage = $eAutoExecute
	  Else
		 ResetToCoCMainScreen()
		 $gAutoStage = $eAutoFindMatch
	 EndIf

   ; Stage Execute Snipe
   Case $eAutoExecute
	  GUICtrlSetData($GUI_AutoStatus, "Auto: Execute Snipe")

	  If AutoSnipeExecuteSnipe($THLocation, $THLeft, $THTop) Then
		 $gAutoStage = $eAutoQueueTraining
	  EndIf

	  GUICtrlSetData($GUI_AutoStatus, "Auto: Snipe Complete")

   EndSwitch
EndFunc

Func AutoSnipeFindMatch(ByRef $location, ByRef $left, ByRef $top, ByRef $zappable)
   DebugWrite("AutoSnipeFindMatch()")
   Local $failCount

   ; Get starting gold, to calculate cost of Next'ing
   GetMyLootNumbers()
   Local $startGold = GUICtrlRead($GUI_MyGold)

   ; Click Attack
   RandomWeightedClick($rMainScreenAttackButton)

   ; Wait for Find a Match button
   $failCount = 10
   While IsButtonPresent($rFindMatchScreenFindAMatchButton) = False And $failCount>0
	  Sleep(1000)
	  $failCount -= 1
   WEnd

   If $failCount = 0 Then
	  DebugWrite("Find Snipable TH failed - timeout waiting for Find a Match button")
	  ResetToCoCMainScreen()
	  Return False
   EndIf

   ; Click Find a Match
   RandomWeightedClick($rFindMatchScreenFindAMatchButton)

   ; Wait for Next button
   $failCount = 30
   While IsButtonPresent($rWaitRaidScreenNextButton) = False And $failCount>0

	  ; See if Shield Is Active screen pops up
	  If WhereAmI() = $eScreenShieldIsActive Then
		 RandomWeightedClick($rShieldIsActivePopupButton)
		 Sleep(500)
	  EndIf

	  Sleep(1000)
	  $failCount -= 1
   WEnd

   If $failCount = 0 Then
	  DebugWrite("AutoSnipe failed - timeout waiting for Wait Raid screen")
	  ResetToCoCMainScreen()
	  Return False
   EndIf

   ; Loop with Next until we find a snipable TH
   Local $nextCount = 1

   While 1
	  If _GUICtrlButton_GetCheck($GUI_AutoSnipeCheckBox) = $BST_UNCHECKED Then Return False

	  Local $continue = True

	  ; Update my loot status on GUI
	  GetMyLootNumbers()

	  ; Get my settings
	  Local $GUIZapDE = (_GUICtrlButton_GetCheck($GUI_AutoRaidZapDE) = $BST_CHECKED)
	  Local $GUIZapDEMin = GUICtrlRead($GUI_AutoRaidZapDEMin)
	  Local $GUIDeadBasesOnly = (_GUICtrlButton_GetCheck($GUI_AutoRaidDeadBases) = $BST_CHECKED)

	  ; Check dead base settings
	  If $GUIDeadBasesOnly And IsColorPresent($rDeadBaseIndicatorColor) Then
		 $continue = False
		 DebugWrite("Not dead base, skipping.")
	  EndIf

	  ; First see if this is a zappable base
	  If $continue Then
		 $zappable = CheckZappableBase()
	  EndIf

	  ; Next, see if we have a TH in the central box area
	  Local $townHall
	  If $continue Then
		 $townHall = GetTownHallLevel($location, $left, $top, $rCentralTownHall[0], $rCentralTownHall[1], $rCentralTownHall[2], $rCentralTownHall[3])
		 If $townHall <> -1 Then
			$continue = False
			DebugWrite("Town Hall level " & $townHall & " found in center, not snipable")
		 EndIf
	  EndIf

	  ; Now find the actual location of the Town Hall: top, middle or bottom
	  If $continue = True Then
		 $townHall = GetTownHallLevel($location, $left, $top)
		 If $townHall <> -1 Then
			If $location = $eTownHallMiddle Then
			   DebugWrite("Snipable TH found in: Middle at " & $left & ", " & $top)
			ElseIf $location = $eTownHallTop Then
			   DebugWrite("Snipable TH found at: Top at " & $left & ", " & $top)
			ElseIf $location = $eTownHallBottom Then
			   DebugWrite("Snipable TH found at: Bottom at " & $left & ", " & $top)
			Else
			   DebugWrite("Snipable TH problem: loc=" & $location & " townhall=" & $townHall)
			EndIf

			ExitLoop
		 Else
			DebugWrite("Could not find Town Hall for sniping.  Obscured?")
		 EndIf
	  EndIf


	  ; Something didn't match - click Next
	  Sleep($gPauseBetweenNexts)
	  RandomWeightedClick($rWaitRaidScreenNextButton)
	  $nextCount+=1

	  ; Sleep and wait for Next button to reappear
	  Sleep(500) ; So the click on the Wait button has time to register
	  $failCount = 30
	  While IsButtonPresent($rWaitRaidScreenNextButton) = False And $failCount>0
		 Sleep(1000)
		 $failCount -= 1
	  WEnd

	  If $failCount = 0 Then
		 DebugWrite("AutoSnipe failed - timeout waiting for Wait Raid screen")
		 ResetToCoCMainScreen()
		 Return False
	  EndIf
   WEnd

   ; Get ending gold, to calculate cost of Next'ing
   GetMyLootNumbers()
   Local $endGold = GUICtrlRead($GUI_MyGold)

   DebugWrite("Gold cost this search: " & $startGold - $endGold & " (" & $nextCount & " nexts).")

   Return $eAutoExecute
EndFunc

Func AutoSnipeExecuteSnipe(Const $THLocation, Const $THLeft, Const $THTop)
   DebugWrite("AutoSnipeExecuteSnipe()")

   ; Move screen
   Local $deployTopOrBot, $actualTHTop
   $deployTopOrBot = AutoSnipeMoveScreen($THLocation, $THTop, $actualTHTop)
   DebugWrite("Town Hall location: " & $THLeft & ", " & $actualTHTop)

   ; Find best deploy spot, based on deployment boxes
   Local $deployBox[4]
   AutoSnipeFindClosestDeployBox($deployTopOrBot, $THLeft, $actualTHTop, $deployBox)

   ; What troops are available?
   Local $troopIndex[$eTroopCount][4]
   FindRaidTroopSlots($gTroopSlotBMPs, $troopIndex)
   Local $barbButton[4] = [$troopIndex[$eTroopBarbarian][0], $troopIndex[$eTroopBarbarian][1], $troopIndex[$eTroopBarbarian][2], $troopIndex[$eTroopBarbarian][3]]
   Local $archButton[4] = [$troopIndex[$eTroopArcher][0], $troopIndex[$eTroopArcher][1], $troopIndex[$eTroopArcher][2], $troopIndex[$eTroopArcher][3]]
   Local $kingButton[4] = [$troopIndex[$eTroopKing][0], $troopIndex[$eTroopKing][1], $troopIndex[$eTroopKing][2], $troopIndex[$eTroopKing][3]]
   Local $queenButton[4] = [$troopIndex[$eTroopQueen][0], $troopIndex[$eTroopQueen][1], $troopIndex[$eTroopQueen][2], $troopIndex[$eTroopQueen][3]]

   ; send troops in waves, check star color region for success
   Local $kingDeployed = False, $queenDeployed = False
   Local $waveDelay = 15000
   Loval $waveTroops = 10

   While IsColorPresent($rFirstStarColor) = False
	  Local $waveTimer = TimerInit()

	  ; Get counts of available troops
	  Local $availableBarbs = GetAvailableTroops($eTroopBarbarian, $troopIndex)
	  Local $availableArchs = GetAvailableTroops($eTroopArcher, $troopIndex)
	  DebugWrite("Troops available: Barbarians=" & $availableBarbs & " Archers=" & $availableArchs)

	  If _GUICtrlButton_GetCheck($GUI_AutoSnipeCheckBox) = $BST_UNCHECKED Then Return False

	  ; Deploy 15 barbs to box
	  If $barbButton[0] <> -1 Then
		 RandomWeightedClick($barbButton)
		 Sleep(500)
		 For $i = 1 To ($availableBarbs<$waveTroops ? $availableBarbs : $waveTroops)
			Local $xClick, $yClick
			RandomCoords($deployBox, $xClick, $yClick)
			_MouseClickFast($xClick, $yClick)
			Sleep($gDeployTroopClickDelay)
		 Next
	  EndIf

	  If IsColorPresent($rFirstStarColor) = True Then ExitLoop

	  If _GUICtrlButton_GetCheck($GUI_AutoSnipeCheckBox) = $BST_UNCHECKED Then Return False

	  ; Deploy 15 archers to box
	  If $archButton[0] <> -1 Then
		 RandomWeightedClick($archButton)
		 Sleep(500)
		 For $i = 1 To ($availableArchs<$waveTroops ? $availableArchs : $waveTroops)
			Local $xClick, $yClick
			RandomCoords($deployBox, $xClick, $yClick)
			_MouseClickFast($xClick, $yClick)
			Sleep($gDeployTroopClickDelay)
		 Next
	  EndIf

	  If IsColorPresent($rFirstStarColor) = True Then ExitLoop

	  If _GUICtrlButton_GetCheck($GUI_AutoSnipeCheckBox) = $BST_UNCHECKED Then Return False

	  ; Deploy King if we ran out of Barbs and power up after 2 seconds
	  If $kingButton[0] <> -1 And $availableBarbs<=$waveTroops And $kingDeployed=False Then
		 RandomWeightedClick($kingButton)
		 Sleep(500)

		 Local $xClick, $yClick
		 RandomCoords($deployBox, $xClick, $yClick)
		 _MouseClickFast($xClick, $yClick)
		 Sleep(2000)

		 RandomWeightedClick($kingButton)
		 Sleep(500)

		 $kingDeployed = True
	  EndIf

	  If _GUICtrlButton_GetCheck($GUI_AutoSnipeCheckBox) = $BST_UNCHECKED Then Return False

	  ; Deploy Queen if we ran out of Archs and power up after 2 seconds
	  If $queenButton[0] <> -1 And $availableArchs<=$waveTroops And $queenDeployed=False Then
		 RandomWeightedClick($queenButton)
		 Sleep(500)

		 Local $xClick, $yClick
		 RandomCoords($deployBox, $xClick, $yClick)
		 _MouseClickFast($xClick, $yClick)
		 Sleep(2000)

		 RandomWeightedClick($queenButton)
		 Sleep(500)

		 $queenDeployed = True
	  EndIf

	  If $availableBarbs=0 And $availableArchs=0 Then ExitLoop

	  ; Wait for timer
	  While TimerDiff($waveTimer) < $waveDelay
		 If _GUICtrlButton_GetCheck($GUI_AutoSnipeCheckBox) = $BST_UNCHECKED Then Return False
		 If IsColorPresent($rFirstStarColor) = True Then ExitLoop 2
		 Sleep(200)
	  WEnd

   WEnd

   If IsColorPresent($rFirstStarColor) Then
	  RandomWeightedClick($rLiveRaidScreenEndBattleButton)
	  Sleep(1000)
	  RandomWeightedClick($rLiveRaidScreenEndBattleConfirmButton)
   EndIf

   ; Wait for end battle
   WaitForBattleEnd(True, True)  ; always wait full 3 minutes, or until all troops are dead

   Return True
EndFunc

Func AutoSnipeMoveScreen(Const $THLocation, Const $THTop, ByRef $actualTop)
   Local $topBot

   ; move to top of screen
   If $THLocation = $eTownHallTop Then
	  DebugWrite("TownHall found at top, moving screen down")
	  MoveScreenDownToTop(False)
	  $topBot = "Top"
	  $actualTop = $THTop

   ; move to bottom of screen
   ElseIf $THLocation = $eTownHallBottom Then
	  DebugWrite("TownHall found at bottom, moving screen up")
	  MoveScreenUpToBottom(False)
	  $topBot = "Bot"
	  $actualTop = $THTop

   ; if found in center, still shift up or down based on location
   ElseIf $THLocation = $eTownHallMiddle Then
	  If $THTop+17 < 275 Then
		 DebugWrite("TownHall found in middle, moving screen down")
		 MoveScreenDownToTop(False)
		 $topBot = "Top"
		 $actualTop = $THTop + 94 ; 94 pixel move; adjust location where TH was found
	  Else
		 DebugWrite("TownHall found in middle, moving screen up")
		 MoveScreenUpToBottom(False)
		 $topBot = "Bot"
		 $actualTop = $THTop - 143 ; 143 pixel move; adjust location where TH was found
	  EndIf

   Else
	  DebugWrite("TownHall location: " & $THLocation & " ERROR, exiting.")
	  Exit

   EndIf

   Return $topBot
EndFunc

Func AutoSnipeFindClosestDeployBox(Const $topOrBot, Const $left, Const $top, ByRef $box)
   Local $bestDistWest, $bestDistEast
   Local $bestWestBox, $bestEastBox

   If $topOrBot = "Top" Then
	  $bestWestBox = FindClosestDeployBox($left+17, $top+17, $NWDeployBoxes, $bestDistWest, $eDeployBoxNWCorner)
	  $bestEastBox = FindClosestDeployBox($left+17, $top+17, $NEDeployBoxes, $bestDistEast, $eDeployBoxNECorner)
	  DebugWrite("Top deploy, best west=" & $bestWestBox & "/" & Round($bestDistWest,2) & " best east=" & $bestEastBox & "/" & Round($bestDistEast,2))

	  If $bestDistWest < $bestDistEast Then
		 $box[0] = $NWDeployBoxes[$bestWestBox][0]
		 $box[1] = $NWDeployBoxes[$bestWestBox][1]
		 $box[2] = $NWDeployBoxes[$bestWestBox][0] + 20
		 $box[3] = $NWDeployBoxes[$bestWestBox][1] + 20
	  Else
		 $box[0] = $NEDeployBoxes[$bestEastBox][2] - 20
		 $box[1] = $NEDeployBoxes[$bestEastBox][1]
		 $box[2] = $NEDeployBoxes[$bestEastBox][2]
		 $box[3] = $NEDeployBoxes[$bestEastBox][1] + 20
	  EndIf

   Else
	  $bestWestBox = FindClosestDeployBox($left+17, $top+17, $SWDeployBoxes, $bestDistWest, $eDeployBoxSWCorner)
	  $bestEastBox = FindClosestDeployBox($left+17, $top+17, $SEDeployBoxes, $bestDistEast, $eDeployBoxSECorner)
	  DebugWrite("Bottom deploy, best west=" & $bestWestBox & "/" & Round($bestDistWest,2) & " best east=" & $bestEastBox & "/" & Round($bestDistEast,2))

	  If $bestDistWest < $bestDistEast Then
		 $box[0] = $SWDeployBoxes[$bestWestBox][0]
		 $box[1] = $SWDeployBoxes[$bestWestBox][3] - 20
		 $box[2] = $SWDeployBoxes[$bestWestBox][0] + 20
		 $box[3] = $SWDeployBoxes[$bestWestBox][3]
	  Else
		 $box[0] = $SEDeployBoxes[$bestEastBox][2] - 20
		 $box[1] = $SEDeployBoxes[$bestEastBox][3] - 20
		 $box[2] = $SEDeployBoxes[$bestEastBox][2]
		 $box[3] = $SEDeployBoxes[$bestEastBox][3]
	  EndIf

   EndIf
EndFunc

Func FindClosestDeployBox(Const $x, Const $y, Const ByRef $boxes, ByRef $bestDist, Const $corner)
   $bestDist = 9999
   Local $bestBox = -1
   For $i = 0 To 20
	  Local $boxX, $boxY
	  If $corner = $eDeployBoxNWCorner Then
		 $boxX = $boxes[$i][0]
		 $boxY = $boxes[$i][1]
	  ElseIf $corner = $eDeployBoxNECorner Then
		 $boxX = $boxes[$i][2]
		 $boxY = $boxes[$i][1]
	  ElseIf $corner = $eDeployBoxSWCorner Then
		 $boxX = $boxes[$i][0]
		 $boxY = $boxes[$i][3]
	  Else ; $eDeployBoxSECorner
		 $boxX = $boxes[$i][2]
		 $boxY = $boxes[$i][3]
	  EndIf

	  Local $dist = DistBetweenTwoPoints($x, $y, $boxX, $boxY)

	  If $dist<=$bestDist Then
		 $bestDist = $dist
		 $bestBox = $i
	  EndIf
   Next

   Return $bestBox
EndFunc


