-- TurnReminderUI
-- Author: Isaac
-- DateCreated: 4/4/2020 1:53:04 PM
--------------------------------------------------------------

-- TODO: Spaces instead of tabs
include("InstanceManager");
include("NotificationPanel");

local TopPanelButtonAdded = false; -- flag to indicate the button was added to the top panel
local UpcomingReminders:table = {};
local NextId:number = 1;

-- TODO: Tidy this up. This is disgusting.
function GetDefaultNotification(id, message, dismissTurn)             -- You need to send a table with at least :
  local localPlayer               = Game.GetLocalPlayer();
    local DefaultNotification                     = {};

    DefaultNotification.IsCustom            = true -- Need to be true to separate custom from game notification
    
    DefaultNotification.GetTypeName         = function() return "NOTIFICATION_TURN_REMINDER"; end
    DefaultNotification.GetPlayerID         = function() return localPlayer; end
    DefaultNotification.GetID               = function() return id + 8192; end  -- Should be unique
    
    DefaultNotification.GetGroup            = function() return NotificationGroups.NONE; end
    DefaultNotification.GetIconName         = function() return "ICON_NOTIFICATION_GENERIC"; end
    DefaultNotification.GetType             = function() return 888888; end -- 888888 is the default handler. 888889 will trigger the event specified by "GetEventOnActivate"
    DefaultNotification.GetEndTurnBlocking  = function() return EndTurnBlockingTypes.NO_ENDTURN_BLOCKING; end
    DefaultNotification.IsIconDisplayable   = function() return true; end
    
    DefaultNotification.IsValidForPhase     = function() return ReadyForPhase; end -- should always be true, your notif should not try to appear before the game is loadind
    
    DefaultNotification.IsAutoNotify        = function() return false; end -- if false everything is automatic, if true you need to give your number of notif... never needed it
    
    DefaultNotification.GetMessage          = function() return "Turn Reminder"; end -- title of your notification, should not be nil.. crash the game :/
    
    DefaultNotification.GetSummary          = function() return message; end -- Summary of the notification that will be displayed, as the message not nil pls
    
    DefaultNotification.CanUserDismiss      = function() return true; end -- should always be true?
    
    DefaultNotification.IsLocationValid     = function() return false; end -- if you want the notification to move the camera somewhere when clicked set true here
    
    DefaultNotification.GetLocation         = function() return 0, 0; end -- and set plot X, Y here
    
    DefaultNotification.IsTargetValid       = function() return false; end -- if you want the notification to select a city or a unit when clicked set true here, no need to give location if you give target
    
    DefaultNotification.GetTarget           = function() return playerID, unitID, PlayerComponentTypes.UNIT; end -- if unit playerID, unitID, PlayerComponentTypes.UNIT or if cityplayerID, cityID, PlayerComponentTypes.CITY 
    
    DefaultNotification.IsVisibleInUI       = function() return true; end -- should always be true?
    
    DefaultNotification.Activate            = function(Boolean) end -- never truly understand this one too? from the game code "Passing true, signals that this is the user trying to do the activation."
    
    DefaultNotification.GetCount            = function() return 1; end -- if you set autonotify to true you need to give count... never used
    
    DefaultNotification.GetAddTurn          = function() return dismissTurn; end -- Give the turn you want your notification to be dissmissed it will dissmiss the turn just after
    DefaultNotification.EraseOnStartTurn    = true; -- if is false won't erase on start turn even if you set "GetAddTurn"
    DefaultNotification.DissmissOnActivate  = false; -- Will dismiss on notification is clicked (need GetType 888889)
    DefaultNotification.GetEventOnActivate  = "Default_Event" -- Name of the Event when GetType is 888889
    
  return DefaultNotification
end











--************************************************************
-- Add the RMT button to the top panel
local function AddButtonToTopPanel()
  print("TurnReminder: AddButtonToTopPanel");
  if not TopPanelButtonAdded then
    local tPanRightStack:table = ContextPtr:LookUpControl("/InGame/TopPanel/RightContents"); -- top panel right stack where clock civilopedia and menu is
    if tPanRightStack ~= nil then
      Controls.TurnReminderTopPanelButton:ChangeParent(tPanRightStack);
      tPanRightStack:AddChildAtIndex(Controls.TurnReminderTopPanelButton, 3);
      tPanRightStack:CalculateSize();
      tPanRightStack:ReprocessAnchoring();
      TopPanelButtonAdded = true;
    end
  end
end

--******************************************************************************
local function ShowDialog()
  print("TurnReminder: ShowDialog");
  Controls.TurnEditBox:SetText("1");
  Controls.ReminderText:SetText("");
  Controls.TurnReminderDialogContainer:SetHide(false);
end

--******************************************************************************
local function HideDialog()
  print("TurnReminder: HideDialog");
  Controls.TurnReminderDialogContainer:SetHide(true);
end

-- Use the same code to get the current turn as in TopPanel.lua, to be consistent with the top panel turn counter
local function CurrentTurn()
  local currentTurn = Game.GetCurrentGameTurn();
  if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_NORMALIZED_TURN") then
    currentTurn = (currentTurn - GameConfiguration.GetStartTurn()) + 1; -- Keep turns starting at 1.
  end
  return currentTurn;
end

--******************************************************************************
local function AddUpcomingReminder(turnsInFuture:number, message:string)
  print("TurnReminder: AddUpcomingReminder(", turnsInFuture, ", ", message, ")");

  UpcomingReminders[tostring(NextId)] = {Turn = CurrentTurn() + turnsInFuture, Message = message, Id = NextId};
  NextId = NextId + 1;
end

--******************************************************************************
local function RefreshUpcomingReminders()
  print("TurnReminder: RefreshUpcomingReminders");

  Controls.UpcomingReminderRows:DestroyAllChildren()
  
  for _, reminder in pairs(UpcomingReminders) do
    reminderInstance = {}
    ContextPtr:BuildInstanceForControl("UpcomingReminderInstance", reminderInstance, Controls.UpcomingReminderRows);
    reminderInstance.Turn:SetText(reminder.Turn);
    reminderInstance.Message:SetText(reminder.Message);

    sortingTag = reminder.Turn * 256 + reminder.Id;
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
    print("There were upcoming reminders!");
    Controls.TurnReminderDialogContainer:SetSizeY(460);
    Controls.TurnReminderDialogUpcomingGrid:SetShow(true);
    Controls.UpcomingReminderHeaders:SetShow(true);
    Controls.UpcomingReminderRowsScrollPanel:SetShow(true);
  else
    print("There were no upcoming reminders!");
    Controls.TurnReminderDialogContainer:SetSizeY(135);
    Controls.TurnReminderDialogUpcomingGrid:SetHide(true);
    Controls.UpcomingReminderHeaders:SetHide(true);
    Controls.UpcomingReminderRowsScrollPanel:SetHide(true);
  end
end

--************************************************************
-- Callback when the Top Panel button is clicked
local function OnTopPanelButtonClick()
  print("TurnReminder: OnTopPanelButtonClick");
  if not Controls.TurnReminderDialogContainer:IsHidden() then
    HideDialog();
  else
    ShowDialog();
  end
end

--************************************************************
-- Callback when the left arrow button is clicked
local function OnTurnEditLeftButtonClick()
  print("TurnReminder: OnTurnEditLeftButtonClick");
  value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if value > 1 then
    Controls.TurnEditBox:SetText(value - 1);
  end
end

--************************************************************
-- Callback when the right arrow button is clicked
local function OnTurnEditRightButtonClick()
  print("TurnReminder: OnTurnEditRightButtonClick");
  value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if value < 9999 then
    Controls.TurnEditBox:SetText(value + 1);
  end
end

local function OnTurnEditBoxCommit()
  print("TurnReminder: OnTurnEditBoxCommit");
  value = tonumber(Controls.TurnEditBox:GetText() or 0);
  if (value < 1) then
    Controls.TurnEditBox:SetText("1");
  end
end

--************************************************************
-- Callback when the OK button in the Turn Reminder dialog is clicked
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

--************************************************************
-- Callback when the number-of-turns box is edited
-- local function
-- end


--************************************************************
-- Callback of the load game UI event
local function OnLoadGameViewStateDone()
  print("TurnReminder: OnLoadGameViewStateDone");
  AddButtonToTopPanel();
  ContextPtr:SetHide(false);  -- TODO: What does this line do? It's very important
end

--************************************************************
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
    if not firstTime then return end
  print("OnPlayerTurnActivated("..playerId..")");  -- TODO: Remove
  if playerId == Game.GetLocalPlayer() then
    currentTurn = CurrentTurn();
    print("OnPlayerTurnActivated(turn = "..currentTurn..")");

    reminders = 0;
    for index, reminder in pairs(UpcomingReminders) do
      if reminder.Turn == currentTurn then
        reminders = reminders + 1;

      local NotificationTurn          =  CurrentTurn()
      notification = GetDefaultNotification(reminder.Id, reminder.Message, currentTurn);
            
      print("SendingReminder");
      LuaEvents.CustomNotification_OnDefaultAddNotification(notification);

      UpcomingReminders[index] = nil
      end
    end
    print(tostring(reminders).." reminder(s)");
    RefreshUpcomingReminders();
  end
end


-- TODO: Have a hotkey to open, and hit ESC to close
print("Start Initialization");

Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
ContextPtr:SetInputHandler(InputHandler, true);

Controls.TurnReminderTopPanelButton:RegisterCallback(Mouse.eLClick, OnTopPanelButtonClick);
Controls.TurnEditLeftButton:RegisterCallback(Mouse.eLClick, OnTurnEditLeftButtonClick);
Controls.TurnEditRightButton:RegisterCallback(Mouse.eLClick, OnTurnEditRightButtonClick);
Controls.AddTurnReminderButton:RegisterCallback(Mouse.eLClick, OnAddTurnReminderButtonClick);
Controls.TurnEditBox:RegisterCommitCallback(OnTurnEditBoxCommit);

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);

print("End Initialization" );