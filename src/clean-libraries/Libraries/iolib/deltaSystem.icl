implementation module deltaSystem;

//  Version 0.84sp
//
//  Operating System dependent constants.
//

// from StdString import String;

/* Keyboard constants */

UpKey        :== '\036';  // Arrow up        in C part: MacUp
DownKey      :== '\037';  // Arrow down      in C part: MacDown
LeftKey      :== '\034';  // Arrow left      in C part: MacLeft
RightKey     :== '\035';  // Arrow right     in C part: MacRight
PgUpKey      :== '\013';  // Page up         in C part: MacPgUp
PgDownKey    :== '\014';  // Page down       in C part: MacPgDown
BeginKey     :== '\001';  // Begin of text   in C part: MacBegin
EndKey       :== '\004';  // End of text     in C part: MacEnd
BackSpKey    :== '\010';  // Backspace       in C part: MacBackSp
DelKey       :== '\177';  // Delete          in C part: MacDel
TabKey       :== '\011';  // Tab             in C part: MacTab
ReturnKey    :== '\015';  // Return          in C part: MacReturn
EnterKey     :== '\003';  // Enter           in C part: MacEnter
EscapeKey    :== '\033';  // Escape          in C part: MacEscape
HelpKey      :== '\005';  // Help            in C part: MacHelp

/* File constants */

DirSeparator :== '/';     // Separator between directories and files in a pathname

/*  Constants to check which of the Modifiers is down. */

ShiftOnly   :== (True,False,False,False);
OptionOnly  :== (False,True,False,False);
CommandOnly :== (False,False,True,True);
ControlOnly :== (False,False,True,True);

from xpath   import get_home_path, get_appl_path;
from xwindow import get_screen_size;
from xdialog import mm_to_pixel_hor,mm_to_pixel_ver;
from StdInt  import class - (-), instance - (Int);
from StdReal  import class * (*), instance * (Real);
from StdString  import class +++ (+++), instance +++({#Char});

HomePath :: !String -> String;
HomePath fname   =   get_home_path 0  +++  "/." +++ fname ;

ApplicationPath :: !String -> String;
ApplicationPath fname   =   get_appl_path 0  +++  "/" +++ fname ;

MaxFixedWindowSize ::    (!Int,!Int);
MaxFixedWindowSize =: (width - 100, height - 100);
    where {
      (width, height)=: get_screen_size 0;
    };

MaxScrollWindowSize ::    (!Int, !Int);
MaxScrollWindowSize =: MaxFixedWindowSize;

MMToHorPixels :: !Real -> Int;
MMToHorPixels n     =  mm_to_pixel_hor n;

MMToVerPixels :: !Real -> Int;
MMToVerPixels n     =  mm_to_pixel_ver n;

InchToHorPixels :: !Real -> Int;
InchToHorPixels n     =  mm_to_pixel_hor (n * 25.4);

InchToVerPixels :: !Real -> Int;
InchToVerPixels n     =  mm_to_pixel_ver (n * 25.4);
