definition module menuDevice;

import ioState;

    
MenuFunctions ::    DeviceFunctions state;

     
  Set :== 1;
  UnSet :== 0;

    

// 	Creation and allocation.
InsertInGroup :: !MenuItemGroupId !Int ![MenuElement s (IOState s)]
                 !(DeviceSystemState s) -> DeviceSystemState s;
DelFromGroupIndex :: !MenuItemGroupId ![Int] !(DeviceSystemState s)
                     -> DeviceSystemState s;
DelFromGroups :: ![MenuItemId] !(DeviceSystemState s) -> DeviceSystemState s;

//	Controlling the Appearance of Items
CheckXWidget :: !Widget !MarkState -> Widget;
SetWidgetAbility :: !Widget !SelectState -> Widget;
SetMenuAbility :: !Widget !SelectState -> Widget;

// general
IdListContainsId :: ![Int] !Int -> Bool;
AddKey :: !KeyShortcut ![KeyShortcut] -> [KeyShortcut];
