-- TurnReminderUI
-- Author: Isaac
-- DateCreated: 4/4/2020 1:53:04 PM
--------------------------------------------------------------

print("Start Initialization");

include("InstanceManager");
include("NotificationPanel");

local TopPanelButtonAdded = false;
local UpcomingReminders:table = {};
local NextId:number = 1;

---------------
-- Utilities --
---------------

local function BuildNotification(id, message, turn)
    local notification = {};

    notification.GetID               = function() return id + 8192; end  -- Must be unique
    notification.GetSummary          = function() return message; end -- Must not be nil
    notification.GetAddTurn          = function() return turn; end -- Notification will be dismissed on the following turn

    notification.IsCustom            = true
    notification.GetTypeName         = function() return "NOTIFICATION_TURN_REMINDER"; end
    notification.GetPlayerID         = function() return Game.GetLocalPlayer(); end
    notification.GetMessage          = function() return "Turn Reminder"; end -- Must not be nil
    notification.GetIconName         = function() return "ICON_NOTIFICATION_GENERIC"; end
    notification.GetGroup            = function() return NotificationGroups.NONE; end
    notification.GetType             = function() return 888888; end -- 888888 is the default handler. 888889 will trigger the event specified by "GetEventOnActivate"
    notification.GetEndTurnBlocking  = function() return EndTurnBlockingTypes.NO_ENDTURN_BLOCKING; end
    notification.IsVisibleInUI       = function() return true; end
    notification.IsIconDisplayable   = function() return true; end
    notification.IsValidForPhase     = function() return true; end
    notification.IsAutoNotify        = function() return false; end
    notification.CanUserDismiss      = function() return true; end
    notification.Activate            = function(Boolean) end
    notification.GetCount            = function() return 1; end
    notification.EraseOnStartTurn    = true;
    
    -- Options to move the camera when the notification is activated
    notification.IsLocationValid     = function() return false; end -- if you want the notification to move the camera somewhere when clicked set true here
    notification.GetLocation         = function() return 0, 0; end -- and set plot X, Y here
    notification.IsTargetValid       = function() return false; end -- if you want the notification to select a city or a unit when clicked set true here, no need to give location if you give target
    notification.GetTarget           = function() return Game.GetLocalPlayer(), nil, nil; end -- PlayerId, EntityId, EntityType (PlayerComponentTypes.{UNIT|CITY}
    
  return notification
end

-- Use the same code to get the current turn as in TopPanel.lua, to be consistent with the top panel turn counter
local function CurrentTurn()
  local currentTurn = Game.GetCurrentGameTurn();
  if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_NORMALIZED_TURN") then
    currentTurn = (currentTurn - GameConfiguration.GetStartTurn()) + 1; -- Keep turns starting at 1.
  end
  return currentTurn;
end

local function AddUpcomingReminder(turnsInFuture:number, message:string)
  print("TurnReminder: AddUpcomingReminder(", turnsInFuture, ", ", message, ")");

  UpcomingReminders[tostring(NextId)] = {Turn = CurrentTurn() + turnsInFuture, Message = message, Id = NextId};
  NextId = NextId + 1;
end

-----------------
-- UI Mutators --
-----------------

local function AddButtonToTopPanel()
  if TopPanelButtonAdded then return end

  print("TurnReminder: AddButtonToTopPanel");
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
  print("TurnReminder: ShowDialog");
  Controls.TurnEditBox:SetText("1");
  Controls.ReminderText:SetText("");
  Controls.TurnReminderDialogContainer:SetHide(false);
end

local function HideDialog()
  print("TurnReminder: HideDialog");
  Controls.TurnReminderDialogContainer:SetHide(true);
end

local function RefreshUpcomingReminders()
  print("TurnReminder: RefreshUpcomingReminders");

  Controls.UpcomingReminderRows:DestroyAllChildren()
  
  for _, reminder in pairs(UpcomingReminders) do
    local reminderInstance = {}
    ContextPtr:BuildInstanceForControl("UpcomingReminderInstance", reminderInstance, Controls.UpcomingReminderRows);
    reminderInstance.Turn:SetText(reminder.Turn);
    reminderInstance.Message:SetText(reminder.Message);

    local sortingTag = reminder.Turn * 256 + reminder.Id;
    Controls.UpcomingReminderRows:GetChildren()[Controls.UpcomingReminderRows:GetNumChildren()]:SetTag(sortingTag);

    reminderInstance.TrashButton:RegisterCallback(
      Mouse.eLClick,
      function()
        print("TurnReminder: TrashButtonCallback(" .. reminder.Id .. ")");
        UpcomingReminders[tostring(reminder.Id)] = nil;
        RefreshUpcomingReminders();
      end
    );
  end

  Controls.UpcomingReminderRows:SortChildren(function(a, b) return a:GetTag() < b:GetTag() end);

  if next(UpcomingReminders) ~= nil then
    Controls.TurnReminderDialogContainer:SetSizeY(460);
    Controls.TurnReminderDialogUpcomingGrid:SetShow(true);
    Controls.UpcomingReminderHeaders:SetShow(true);
    Controls.UpcomingReminderRowsScrollPanel:SetShow(true);
  else
    Controls.TurnReminderDialogContainer:SetSizeY(135);
    Controls.TurnReminderDialogUpcomingGrid:SetHide(true);
    Controls.UpcomingReminderHeaders:SetHide(true);
    Controls.UpcomingReminderRowsScrollPanel:SetHide(true);
  end
end

---------------
-- Callbacks --
---------------

-- The top panel button next to the CivPedia
local function OnTopPanelButtonClick()
  print("TurnReminder: OnTopPanelButtonClick");
  if not Controls.TurnReminderDialogContainer:IsHidden() then
    HideDialog();
  else
    ShowDialog();
  end
end

-- The decrement arrow to the left of the TurnEditBox
local function OnTurnEditLeftButtonClick()
  print("TurnReminder: OnTurnEditLeftButtonClick");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if value > 1 then
    Controls.TurnEditBox:SetText(value - 1);
  end
end

-- The increment arrow to the right of the TurnEditBox
local function OnTurnEditRightButtonClick()
  print("TurnReminder: OnTurnEditRightButtonClick");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if value < 9999 then
    Controls.TurnEditBox:SetText(value + 1);
  end
end

-- The box that specifieds the number of turns in the future to set the reminder
local function OnTurnEditBoxCommit()
  print("TurnReminder: OnTurnEditBoxCommit");
  local value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if (value < 1) then
    Controls.TurnEditBox:SetText("1");
  end
end

-- The OK button on the right of the dialog
local function OnAddTurnReminderButtonClick()
  print("TurnReminder: OnAddTurnReminderButtonClick");

  if (Controls.ReminderText:GetText() or "") == "" then
    HideDialog()
  else
    AddUpcomingReminder(tonumber(Controls.TurnEditBox:GetText() or 0), Controls.ReminderText:GetText());
    RefreshUpcomingReminders();
    Controls.ReminderText:SetText("");
  end
end


-- Callback when we load into the game for the first time
local function OnLoadGameViewStateDone()
  print("TurnReminder: OnLoadGameViewStateDone");
  AddButtonToTopPanel();
  ContextPtr:SetHide(false);
end

-- Callback for keystrokes
local function InputHandler(input:table)
  if not Controls.TurnReminderDialogContainer:IsHidden() and input:GetMessageType() == KeyEvents.KeyUp then
    local key = input:GetKey();
    print("TurnReminder: InputHandler(key = ", key, ")");

    if key == Keys.VK_ESCAPE then
      OnTopPanelButtonClick();
      return true;
    -- TODO: Try to get Enter to work consistently
    --elseif key == 102 then
      --OnAddTurnReminderButtonClick();
      --return true;
    end
  end
  -- TODO: Add a hotkey like this for opening the window.
  --if key == 31  and input:IsAltDown() and not input:IsShiftDown()  and not input:IsControlDown() then
    --OnTopPanelButtonClick();
    --return true;
  --end
end

local function OnPlayerTurnActivated(playerId, firstTime)
  if not (firstTime and playerId == Game.GetLocalPlayer()) then return end

  local currentTurn = CurrentTurn();
  print("TurnReminder: OnPlayerTurnActivated(turn = "..currentTurn..")");

  for index, reminder in pairs(UpcomingReminders) do
    if reminder.Turn == currentTurn then
      local NotificationTurn = CurrentTurn()
      local notification = BuildNotification(reminder.Id, reminder.Message, currentTurn);
            
      LuaEvents.CustomNotification_OnDefaultAddNotification(notification);

      UpcomingReminders[index] = nil
    end
  end
  RefreshUpcomingReminders();
end

Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
ContextPtr:SetInputHandler(InputHandler, true);

Controls.TurnReminderTopPanelButton:RegisterCallback(Mouse.eLClick, OnTopPanelButtonClick);
Controls.TurnEditLeftButton:RegisterCallback(Mouse.eLClick, OnTurnEditLeftButtonClick);
Controls.TurnEditRightButton:RegisterCallback(Mouse.eLClick, OnTurnEditRightButtonClick);
Controls.AddTurnReminderButton:RegisterCallback(Mouse.eLClick, OnAddTurnReminderButtonClick);
Controls.TurnEditBox:RegisterCommitCallback(OnTurnEditBoxCommit);

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);

print("End Initialization" );