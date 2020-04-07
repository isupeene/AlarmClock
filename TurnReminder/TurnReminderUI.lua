-- TurnReminderUI
-- Author: Isaac
-- DateCreated: 4/4/2020 1:53:04 PM
--------------------------------------------------------------

local function Verbose(message)
  -- print(message);
end

Verbose("Start Initialization");

include("InstanceManager");  -- TODO: Does this do anything?

local UpcomingReminders = {};

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

-- Returns an iterator over t ordered by f, without modifying t.
local function Sorted(t, f)
  local sortedValues = {};
  for key, value in pairs(t) do table.insert(sortedValues, {Key=key, Value=value}) end
  table.sort(sortedValues, function(a, b) return f(a.Value, b.Value) end);
  
  local i = 0;
  return function()
    i = i + 1;
    if sortedValues[i] == nil then return nil end
    return sortedValues[i].Key, sortedValues[i].Value;
  end
end

local function AddUpcomingReminder(turnsInFuture:number, message:string)
  Verbose("TurnReminder: AddUpcomingReminder(", turnsInFuture, ", ", message, ")");
  UpcomingReminders[tostring(CurrentTurn() + turnsInFuture)] = message;  -- TODO: Is tostring needed here?
end

-----------------
-- UI Mutators --
-----------------

local TopPanelButtonAdded = false; -- TODO: Is this needed?
local function AddButtonToTopPanel()
  if TopPanelButtonAdded then return end

  Verbose("TurnReminder: AddButtonToTopPanel");
  local topPanel = ContextPtr:LookUpControl("/InGame/TopPanel/RightContents"); -- top panel right stack where clock civilopedia and menu is
  if topPanel ~= nil then
    Controls.TurnReminderTopPanelButton:ChangeParent(topPanel);
    topPanel:AddChildAtIndex(Controls.TurnReminderTopPanelButton, 3);
    topPanel:CalculateSize();
    topPanel:ReprocessAnchoring();
    TopPanelButtonAdded = true;
  end
end

local function ShowDialog()
  Verbose("TurnReminder: ShowDialog");
  Controls.TurnEditBox:SetText("1");
  Controls.ReminderText:SetText("");
  Controls.TurnReminderDialogContainer:SetHide(false);

  Controls.ReminderText:TakeFocus();
end

local function HideDialog()
  Verbose("TurnReminder: HideDialog");
  Controls.TurnReminderDialogContainer:SetHide(true);
  Controls.ReminderText:DropFocus();
end

local function RefreshUpcomingReminders()
  Verbose("TurnReminder: RefreshUpcomingReminders");

  Controls.UpcomingReminderRows:DestroyAllChildren()
  
  for turn, message in pairs(UpcomingReminders) do
    local reminderInstance = {}
    ContextPtr:BuildInstanceForControl("UpcomingReminderInstance", reminderInstance, Controls.UpcomingReminderRows);
    reminderInstance.Turn:SetText(turn);
    reminderInstance.Message:SetText(message);
    
    Controls.UpcomingReminderRows:GetChildren()[Controls.UpcomingReminderRows:GetNumChildren()]:SetTag(tonumber(turn));

    reminderInstance.TrashButton:RegisterCallback(
      Mouse.eLClick,
      function()
        Verbose("TurnReminder: TrashButtonCallback(" .. turn .. ")");
        UpcomingReminders[turn] = nil;
        RefreshUpcomingReminders();
      end
    );
  end
  
  -- Roundabout way of sorting the rows by turn number, since it's not clear how to access the actual value.  TODO: Figure out?
  Controls.UpcomingReminderRows:SortChildren(function(a, b) return a:GetTag() < b:GetTag() end);

  if next(UpcomingReminders) ~= nil then
    Controls.TurnReminderDialogContainer:SetSizeY(460);
    Controls.UpcomingRemindersStack:SetShow(true);
  else
    Controls.TurnReminderDialogContainer:SetSizeY(135);
    Controls.UpcomingRemindersStack:SetHide(true);
  end
end

local function ToggleDialogVisibility()
  Verbose("TurnReminder: ToggleDialogVisibility");
  if not Controls.TurnReminderDialogContainer:IsHidden() then
    HideDialog();
  else
    ShowDialog();
  end
end

local function CommitEntry()
  Verbose("TurnReminder: CommitEntry");

  AddUpcomingReminder(tonumber(Controls.TurnEditBox:GetText() or 0), Controls.ReminderText:GetText());
  RefreshUpcomingReminders();
  Controls.ReminderText:SetText("");
end

---------------
-- Callbacks --
---------------

-- The OK button on the right of the dialog
local function OnAddTurnReminderButtonClick()
  Verbose("TurnReminder: OnAddTurnReminderButtonClick");

  if (Controls.ReminderText:GetText() or "") == "" then
    HideDialog();
  else
    CommitEntry();
    Controls.ReminderText:TakeFocus();
  end
end

-- The top panel button next to the CivPedia
local function OnTopPanelButtonClick()
  Verbose("TurnReminder: OnTopPanelButtonClick");
  ToggleDialogVisibility()
end

-- The decrement arrow to the left of the TurnEditBox
local function OnTurnEditLeftButtonClick()
  Verbose("TurnReminder: OnTurnEditLeftButtonClick");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if value > 1 then
    Controls.TurnEditBox:SetText(value - 1);
  end
  Controls.ReminderText:TakeFocus();
end

-- The increment arrow to the right of the TurnEditBox
local function OnTurnEditRightButtonClick()
  Verbose("TurnReminder: OnTurnEditRightButtonClick");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if value < 9999 then
    Controls.TurnEditBox:SetText(value + 1);
  end
  Controls.ReminderText:TakeFocus();
end

-- The box that specifies the number of turns in the future to set the reminder
local function OnTurnEditBoxCommit()
  Verbose("TurnReminder: OnTurnEditBoxCommit");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if (value < 1) then
    Controls.TurnEditBox:SetText("1");
  end
end

local function OnReminderTextCommit()
  Verbose("TurnReminder: OnReminderTextCommit");
  OnAddTurnReminderButtonClick();
end

-- Callback when we load into the game for the first time
local function OnLoadGameViewStateDone()
  Verbose("TurnReminder: OnLoadGameViewStateDone");
  AddButtonToTopPanel();
  ContextPtr:SetHide(false);
end

-- Callback for keystrokes
local function InputHandler(input:table)
  local key = input:GetKey();
  -- Note that we use KeyUp for the ESC and Enter keys, since this is what the game is listening to.
  -- Handling KeyUp prevents us from getting a double-input, and e.g. opening the game menu or
  -- progressing to the next turn.
  if not Controls.TurnReminderDialogContainer:IsHidden() and input:GetMessageType() == KeyEvents.KeyUp then
    if key == Keys.VK_ESCAPE then
      Verbose("TurnReminder: InputHandler(ESC)");
      HideDialog();
      return true;
    elseif key == 102 then
      Verbose("TurnReminder: InputHandler(Enter)");
      OnAddTurnReminderButtonClick();
      return true;
    end
  end

  if input:GetMessageType() == KeyEvents.KeyDown and key == 18 and input:IsAltDown() and not input:IsShiftDown() and not input:IsControlDown() then
    Verbose("TurnReminder: InputHandler(Alt+R)");
    ToggleDialogVisibility();
    return true;
  end
end

local function OnPlayerTurnActivated(playerId, firstTime)
  if not (firstTime and playerId == Game.GetLocalPlayer()) then return end

  local currentTurn = tostring(CurrentTurn());
  Verbose("TurnReminder: OnPlayerTurnActivated(turn = "..currentTurn..")");

  if UpcomingReminders[currentTurn] then
    NotificationManager.SendNotification(playerId, NotificationTypes.USER_DEFINED_1, "LOC_TR_NOTIF_MSG", UpcomingReminders[currentTurn]);
     UpcomingReminders[currentTurn] = nil;
  end
  RefreshUpcomingReminders();
end

----------------
-- Main Setup --
----------------

Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
ContextPtr:SetInputHandler(InputHandler, true);

Controls.TurnReminderTopPanelButton:RegisterCallback(Mouse.eLClick, OnTopPanelButtonClick);
Controls.TurnEditLeftButton:RegisterCallback(Mouse.eLClick, OnTurnEditLeftButtonClick);
Controls.TurnEditRightButton:RegisterCallback(Mouse.eLClick, OnTurnEditRightButtonClick);
Controls.AddTurnReminderButton:RegisterCallback(Mouse.eLClick, OnAddTurnReminderButtonClick);
Controls.TurnEditBox:RegisterCommitCallback(OnTurnEditBoxCommit);
Controls.ReminderText:RegisterCommitCallback(OnReminderTextCommit);

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);

Verbose("End Initialization" );