definition module deltaSystem;

//  Version 0.8

//
//  Operating System dependent constants and functions. 
//
     

/*  Keyboard constants */

    UpKey           :== '\036';  // Arrow up
    DownKey         :== '\037';  // Arrow down
    LeftKey         :== '\034';  // Arrow left
    RightKey        :== '\035';  // Arrow right
    PgUpKey         :== '\013';  // Page up
    PgDownKey       :==  '\014'; // Page down
    BeginKey        :== '\001';  // Begin of text
    EndKey          :== '\004';  // End of text
    BackSpKey       :== '\010';  // Backspace
    DelKey          :== '\177';  // Delete
    TabKey          :== '\011';  // Tab
    ReturnKey       :== '\015';  // Return
    EnterKey        :== '\003';  // Enter
    EscapeKey       :== '\033';  // Escape
    HelpKey         :== '\005';  // Help


/*  File constants */

    DirSeparator    :== '/';     // Separator between directories and
                                // files in a pathname

/*  Constants to check which of the Modifiers is down. */

    ShiftOnly       :== (True,False,False,False);
    OptionOnly      :== (False,True,False,False);
    CommandOnly     :== (False,False,True,True);
    ControlOnly     :== (False,False,True,True);

    
/* The functions HomePath and ApplicationPath prefix the pathname given
   to them with the full pathnames of the 'home' and 'application'
   directory.
   The 'home' directory is the home directory of the user (set in the HOME
   environment variable). The 'application' directory is the directory in
   which the application that did the call to ApplicationPath resides.
   The 'home' directory should be used to store settings-files (containing
   preferences, high-scores etc.). The function HomePath automatically
   prefixes the given filename with dot ('.').
   The 'application' directory should be used to store files that are used
   read-only by the application, such as help files. */
 
HomePath :: !String -> String;
ApplicationPath :: !String -> String;

/* The maximum size such that a window will fit the screen.
   For FixedWindows this is the maximum size such that the window
   will not become a ScrollWindow. */

MaxFixedWindowSize ::    (!Int,!Int);
MaxScrollWindowSize ::    (!Int, !Int);

/* Calculations from millimeters an inches to screen pixels */

MMToHorPixels :: !Real -> Int;
MMToVerPixels :: !Real -> Int;
InchToHorPixels :: !Real -> Int;
InchToVerPixels :: !Real -> Int;
