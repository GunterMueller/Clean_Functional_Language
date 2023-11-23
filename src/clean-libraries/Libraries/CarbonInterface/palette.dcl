definition module palette;

import mac_types;

NewPalette :: !Int !Int !Int !Int !Toolbox -> Toolbox;
DisposePalette :: !Int !Toolbox -> Toolbox;
ActivatePalette :: !WindowPtr !Toolbox -> Toolbox;
SetPalette :: !WindowPtr !Int !Bool !Toolbox -> Toolbox;
GetPalette :: !WindowPtr !Toolbox -> (!Int, !Toolbox);
SetEntryColor :: !Int !Int !(!Int,!Int,!Int) !Toolbox -> Toolbox;
