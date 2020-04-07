-- AlarmClock_UI
-- Author: Isaac Supeene
-- DateCreated: 4/4/2020 1:53:04 PM
--------------------------------------------------------------

local function Verbose(message)
  -- print(message);
end

Verbose("Start Initialization");

local UpcomingAlarms = {};

---------------
-- Utilities --
---------------

-- Use the same code to get the current turn as in TopPanel.lua, to be consistent with the top panel turn counter
local function CurrentTurn()
  local currentTurn = Game.GetCurrentGameTurn();
  if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_NORMALIZED_TURN") then
    currentTurn = (currentTurn - GameConfiguration.GetStartTurn()) + 1; -- Keep turns starting at 1.
  end
  return currentTurn;
end

local function AddUpcomingAlarm(turnsInFuture, message)
  Verbose("AlarmClock: AddUpcomingAlarm(", turnsInFuture, ", ", message, ")");
  UpcomingAlarms[CurrentTurn() + turnsInFuture] = message;
end

local function ChildById(parent, childId)
  if not childId:find("%.") then
    for index, child in pairs(parent:GetChildren()) do
      if child:GetID() == childId then return child end
    end
    return nil;
  end

  -- Handle hierarchical IDs
  local control = parent;
  for id in childId:gmatch("([^%.]+)") do
    control = ChildById(control, id)
    if not control then return nil end
  end
  return control
end

-----------------
-- UI Mutators --
-----------------

local function AddButtonToTopPanel()
  Verbose("AlarmClock: AddButtonToTopPanel");

  local topPanel = ContextPtr:LookUpControl("/InGame/TopPanel/RightContents"); -- Top-right stack with Clock, Civilopedia, and Menu
  Controls.AlarmClockTopPanelButton:ChangeParent(topPanel);
  topPanel:AddChildAtIndex(Controls.AlarmClockTopPanelButton, 3); -- Insert between the Clock and Civilopedia
  topPanel:CalculateSize();
  topPanel:ReprocessAnchoring();
end

local function ShowDialog()
  Verbose("AlarmClock: ShowDialog");
  Controls.TurnEditBox:SetText("1");
  Controls.AlarmText:SetText("");
  Controls.AlarmClockDialogContainer:SetHide(false);

  Controls.AlarmText:TakeFocus();
end

local function HideDialog()
  Verbose("AlarmClock: HideDialog");
  Controls.AlarmClockDialogContainer:SetHide(true);
  Controls.AlarmText:DropFocus();
end

local function RefreshUpcomingAlarms()
  Verbose("AlarmClock: RefreshUpcomingAlarms");

  Controls.UpcomingAlarmRows:DestroyAllChildren()
  
  for turn, message in pairs(UpcomingAlarms) do
    local alarmInstance = {}
    ContextPtr:BuildInstanceForControl("UpcomingAlarmInstance", alarmInstance, Controls.UpcomingAlarmRows);
    alarmInstance.Turn:SetText(turn);
    alarmInstance.Message:SetText(message);

    alarmInstance.TrashButton:RegisterCallback(
      Mouse.eLClick,
      function()
        Verbose("AlarmClock: TrashButtonCallback(" .. turn .. ")");
        UpcomingAlarms[turn] = nil;
        RefreshUpcomingAlarms();
      end
    );
  end
  
  local GetTurnForRow = function(row) return tonumber(ChildById(row, "AlarmRow.AlarmColumnTurn.Turn"):GetText()) end;
  Controls.UpcomingAlarmRows:SortChildren(function(a, b) return GetTurnForRow(a) < GetTurnForRow(b) end);

  if next(UpcomingAlarms) ~= nil then
    Controls.AlarmClockDialogContainer:SetSizeY(460);
    Controls.UpcomingAlarmsStack:SetShow(true);
  else
    Controls.AlarmClockDialogContainer:SetSizeY(135);
    Controls.UpcomingAlarmsStack:SetHide(true);
  end
end

local function ToggleDialogVisibility()
  Verbose("AlarmClock: ToggleDialogVisibility");
  if not Controls.AlarmClockDialogContainer:IsHidden() then
    HideDialog();
  else
    ShowDialog();
  end
end

local function CommitEntry()
  Verbose("AlarmClock: CommitEntry");

  AddUpcomingAlarm(tonumber(Controls.TurnEditBox:GetText() or 0), Controls.AlarmText:GetText());
  RefreshUpcomingAlarms();
  Controls.AlarmText:SetText("");
end

---------------
-- Callbacks --
---------------

-- The OK button on the right of the dialog
local function OnAddAlarmClockButtonClick()
  Verbose("AlarmClock: OnAddAlarmClockButtonClick");

  if (Controls.AlarmText:GetText() or "") == "" then
    HideDialog();
  else
    CommitEntry();
    Controls.AlarmText:TakeFocus();
  end
end

-- The top panel button next to the CivPedia
local function OnTopPanelButtonClick()
  Verbose("AlarmClock: OnTopPanelButtonClick");
  ToggleDialogVisibility()
end

-- The decrement arrow to the left of the TurnEditBox
local function OnTurnEditLeftButtonClick()
  Verbose("AlarmClock: OnTurnEditLeftButtonClick");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if value > 1 then
    Controls.TurnEditBox:SetText(value - 1);
  end
  Controls.AlarmText:TakeFocus();
end

-- The increment arrow to the right of the TurnEditBox
local function OnTurnEditRightButtonClick()
  Verbose("AlarmClock: OnTurnEditRightButtonClick");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if value < 9999 then
    Controls.TurnEditBox:SetText(value + 1);
  end
  Controls.AlarmText:TakeFocus();
end

-- The box that specifies the number of turns in the future to trigger the alarm
local function OnTurnEditBoxCommit()
  Verbose("AlarmClock: OnTurnEditBoxCommit");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if (value < 1) then
    Controls.TurnEditBox:SetText("1");
  end
end

local function OnAlarmTextCommit()
  Verbose("AlarmClock: OnAlarmTextCommit");
  OnAddAlarmClockButtonClick();
end

-- Callback when we load into the game for the first time
local function OnLoadGameViewStateDone()
  Verbose("AlarmClock: OnLoadGameViewStateDone");
  AddButtonToTopPanel();
  ContextPtr:SetHide(false);
end

-- Callback for keystrokes
local function InputHandler(input:table)
  local key = input:GetKey();
  -- Note that we use KeyUp for the ESC and Enter keys, since this is what the game is listening to.
  -- Handling KeyUp prevents us from getting a double-input, and e.g. opening the game menu or
  -- progressing to the next turn.
  if not Controls.AlarmClockDialogContainer:IsHidden() and input:GetMessageType() == KeyEvents.KeyUp then
    if key == Keys.VK_ESCAPE then
      Verbose("AlarmClock: InputHandler(ESC)");
      HideDialog();
      return true;
    elseif key == 102 then
      Verbose("AlarmClock: InputHandler(Enter)");
      OnAddAlarmClockButtonClick();
      return true;
    end
  end

  if input:GetMessageType() == KeyEvents.KeyDown and key == 18 and input:IsAltDown() and not input:IsShiftDown() and not input:IsControlDown() then
    Verbose("AlarmClock: InputHandler(Alt+R)");
    ToggleDialogVisibility();
    return true;
  end
end

local function OnPlayerTurnActivated(playerId, firstTime)
  if not (firstTime and playerId == Game.GetLocalPlayer()) then return end

  local currentTurn = CurrentTurn();
  Verbose("AlarmClock: OnPlayerTurnActivated(turn = "..currentTurn..")");

  if UpcomingAlarms[currentTurn] then
    NotificationManager.SendNotification(playerId, "NOTIFICATION_ALARM_CLOCK", "LOC_AC_NOTIF_MSG", UpcomingAlarms[currentTurn], currentTurn);
    UpcomingAlarms[currentTurn] = nil;
  end
  RefreshUpcomingAlarms();
end

----------------
-- Main Setup --
----------------

Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
ContextPtr:SetInputHandler(InputHandler, true);

Controls.AlarmClockTopPanelButton:RegisterCallback(Mouse.eLClick, OnTopPanelButtonClick);
Controls.TurnEditLeftButton:RegisterCallback(Mouse.eLClick, OnTurnEditLeftButtonClick);
Controls.TurnEditRightButton:RegisterCallback(Mouse.eLClick, OnTurnEditRightButtonClick);
Controls.AddAlarmClockButton:RegisterCallback(Mouse.eLClick, OnAddAlarmClockButtonClick);
Controls.TurnEditBox:RegisterCommitCallback(OnTurnEditBoxCommit);
Controls.AlarmText:RegisterCommitCallback(OnAlarmTextCommit);

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);

Verbose("End Initialization" );