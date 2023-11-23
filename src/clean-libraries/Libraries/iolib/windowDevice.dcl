definition module windowDevice;


import xtypes, ioState, deltaIOSystem, deltaPicture;


    

WindowFunctions ::    DeviceFunctions s;

Open_windows :: ![WindowDef s (IOState s)] !(WindowHandles s)
   -> WindowHandles s;
ReOpen_window :: !Widget !Widget !(WindowDef s (IOState s))
   -> WindowHandle s;

Close_window :: !Window -> Window;

WindowDeviceNotEmpty :: !(DeviceSystemState s) -> Bool;
EventToMouse :: !MouseEvent -> MouseState;

GetPictureOffset ::          !Widget   !(DeviceSystemState s) -> (!Int,!Int);
GetWindowHandleFromId ::     !WindowId !(DeviceSystemState s) -> (!Bool, !Window);
GetWindowHandleFromDevice :: !WindowId !(DeviceSystemState s)
   -> [WindowHandle s];
PutWindowHandleInDevice :: !WindowId ![WindowHandle s]
      !(DeviceSystemState s)
   -> DeviceSystemState s;
SetActiveWindowHandle :: !Widget !(IOState s) -> IOState s;

Align_thumb :: !Int !Int !Int !Int -> Int;
CollectUpdateArea ::           !Widget -> UpdateArea;
StartUpdate ::     !UpdateArea !Widget -> UpdateArea;
EndUpdate :: !(!*s, !IOState *s) !Widget -> (!*s, !IOState *s);
Draw_in_window :: !Window !(!Int,!Int) ![DrawFunction] -> Window;
ValidateWindow :: !(WindowDef s (IOState s)) -> (!Bool, !WindowDef s (IOState s));


// Access-rules on WindowDefinitions.

WindowDef_WindowId ::          !(WindowDef s io) -> WindowId;
WindowDef_Position ::          !(WindowDef s io) -> WindowPos;
WindowDef_Domain ::            !(WindowDef s io) -> PictureDomain;
WindowDef_Title ::             !(WindowDef s io) -> String;
WindowDef_ScrollBars ::        !(WindowDef s io) -> (!ScrollBarDef, !ScrollBarDef);
WindowDef_MinimumWindowSize :: !(WindowDef s io) -> MinimumWindowSize;
WindowDef_InitialSize ::       !(WindowDef s io) -> InitialWindowSize;
WindowDef_Update ::            !(WindowDef s io) -> UpdateFunction s;
WindowDef_Attributes ::        !(WindowDef s io) -> [WindowAttribute s io];
WindowDef_SetTitle ::          !(WindowDef s io) !WindowTitle        -> WindowDef s io;
WindowDef_SetUpdate ::         !(WindowDef s io) !(UpdateFunction s) -> WindowDef s io;
WindowDef_SetPictureDomain ::  !(WindowDef s io) !PictureDomain      -> WindowDef s io;
WindowDef_SetAttributes :: !(WindowDef s io) ![WindowAttribute s io] -> WindowDef s io;

