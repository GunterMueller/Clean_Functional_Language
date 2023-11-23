implementation module windowDevice;

import StdClass,StdChar,StdInt,StdBool,StdMisc,StdString;
import commonDef,deltaIOSystem,misc;
import xkernel,xwindow,xevent,xtypes;
from xdialog import popup_modelessdialog;
import ioState,picture,cursorInternal;
from deltaWindow import CloseWindows;

Scrollable :== 0;
FixedSize  :== 1;

WindowFunctions ::    DeviceFunctions s;
WindowFunctions = (ShowWindow,OpenWindow,WindowIO,CloseWindow,HideWindow);

OpenWindow :: !(DeviceSystem s (IOState s)) !(IOState s) -> IOState s;
OpenWindow (WindowSystem w_defs) io_state
   #!
		strict1=strict1;
	=
		IOStateSetDevice io_state (WindowSystemState strict1);
	where {
	strict1=(Open_windows w_defs []);
	};

Open_windows :: ![WindowDef s (IOState s)] !(WindowHandles s)
   -> WindowHandles s;
Open_windows [w_def : w_defs] windows
   =  Open_windows w_defs (Open_windows` w_def` windows);
      where {
      (changed,w_def`)=: ValidateWindow w_def;
      };
Open_windows w_defs windows =  windows;

Open_windows` :: !(WindowDef s (IOState s)) !(WindowHandles s)
   -> WindowHandles s;
Open_windows` w_def=: (ScrollWindow id pos title hsbar vsbar domain
                                     msize isize upd atts) windows
    | WindowIdNotUsed id windows 
	    #
	      (win, pic)= Open_window pos title hsbar vsbar domain msize isize;
	    #!
	      window`   = activate_window (SetWindowAttributes win atts);
		=
			[(w_def`, (window`,pic)) : windows];
   =  windows;
      where {
      w_def`    =: ScrollWindow id pos title hsbar vsbar domain msize isize upd
                               (AddDefaultGoAway id atts);
      };
Open_windows` w_def=: (FixedWindow id pos title domain upd atts) windows| WindowIdNotUsed id windows
	#
      (win, pic)= Open_fs_window pos title domain;
	#!
      window`   = activate_window (SetWindowAttributes win atts);
	=
		[(w_def`, (window`,pic)) : windows];
   =  windows;
      where {
      w_def`    =: FixedWindow id pos title domain upd (AddDefaultGoAway id atts);
      };

AddDefaultGoAway :: !WindowId ![WindowAttribute s (IOState s)]
   -> [WindowAttribute s (IOState s)];
AddDefaultGoAway id atts=:[GoAway func : rest] =  atts;
AddDefaultGoAway id [attr : rest]
   =  [attr : AddDefaultGoAway id rest];
AddDefaultGoAway id atts =  [GoAway (DefaultGoAway id)];

DefaultGoAway :: !WindowId !*s !(IOState *s) -> (!*s, !IOState *s);
DefaultGoAway id s io =  (s, CloseWindows [id] io);


ReOpen_window :: !Widget !Widget !(WindowDef s (IOState s))
   -> WindowHandle s;
ReOpen_window active oldwindow w_def=: (ScrollWindow id pos title hsbar vsbar domain msize isize upd atts)
   #!
      strict2=Open_window pos` title hsbar vsbar domain msize isize;
   #
      (win, pic)= strict2;
    #
      window`   = SetWindowAttributes win atts;
    | active == oldwindow
    #!
		strict1=activate_window window`;
	=
		(w_def, (strict1,pic));
	=
		(w_def, (window`,pic));
      where {
      pos`      =: Evaluate_2 pos (destroy_widget oldwindow);
		};

Open_window :: !WindowPos !WindowTitle !ScrollBarDef !ScrollBarDef !PictureDomain
      !MinimumWindowSize !InitialWindowSize
   -> Window;
Open_window (xw,yw) title hsbar=: (ScrollBar (Thumb hthumb) (Scroll hscroll)) vsbar=: (ScrollBar (Thumb vthumb) (Scroll vscroll)) ((x0,y0),(x1,y1)) (wm,hm) (wi,hi)
	#!
      strict1=create_window Scrollable xw yw x0 y0 title hthumb hscroll
                                 vthumb vscroll w h wm hm wi hi;
    #  (pic, win)= strict1;
	=
		(win, NewXPicture pic);
    where {
      w=: x1 - x0;
      h=: y1 - y0;
	};

Open_fs_window :: !WindowPos !WindowTitle !PictureDomain -> Window;
Open_fs_window (xw,yw) title ((x0,y0),(x1,y1))
   #!
      strict1=create_window FixedSize xw yw x0 y0 title x0 0 y0 0 w h 0 0 w h;
   #   (pic, win)= strict1;  // Halbe: was: ...title 0 0 0 0 w h...
	=
		(win, NewXPicture pic);
    where {
      w=: x1 - x0;
      h=: y1 - y0;
	};

WindowIdNotUsed :: !Int !(WindowHandles s) -> Bool;
WindowIdNotUsed id [(w_def,(w,p)) : windows]
   | id ==  WindowDef_WindowId w_def  =  Evaluate_2 False (activate_window w);
   =  WindowIdNotUsed id windows;
WindowIdNotUsed id windows =  True;

CloseWindow :: !(IOState s) -> IOState s;
CloseWindow io_state
   =  UEvaluate_2 (IOStateRemoveDevice io_state` WindowDevice)
                  (Close_windows windows);
      where {
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

Close_windows :: !(DeviceSystemState s) -> WindowHandles s;
Close_windows (WindowSystemState windows) =  Close_windows` windows;

Close_windows` :: !(WindowHandles s) -> WindowHandles s;
Close_windows` [(w_def, window) : windows]
   =  Evaluate_2 (Close_windows` windows) (Close_window window); 
Close_windows` windows =  windows;

Close_window :: !Window -> Window;
Close_window (win,pic) =  (destroy_widget win,pic);

WindowDeviceNotEmpty :: !(DeviceSystemState s) -> Bool;
WindowDeviceNotEmpty (WindowSystemState []) =  False;
WindowDeviceNotEmpty device =  True;


/* Handling all window I/O.
   First we check whether it is a window event and next what window event.
*/
WindowIO :: !Event !*s !(IOState *s) -> (!Bool, !*s, !IOState *s);
WindowIO (w, XWindowDevice, e) s io_state
   #!
      strict1=get_window_event e;
   #
      (s`, io`)= WindowIO` (w, strict1, e) s io_state;
	=
		(True, s`, io`);
WindowIO no_window_event s io_state =  (False, s, io_state);

WindowIO` :: !Event !*s !(IOState *s) -> (!*s, !IOState *s);
WindowIO` (w, XWindowUpdate, e) s io_state
    #  (windows,io_state`)= IOStateGetDevice io_state WindowDevice;
   #!
      area      = CollectUpdateArea w;
      update    = GetWindowUpdateFunction w windows;
      window    = GetWindowHandle w windows;
      offset    = GetPictureOffset w windows;
      strict2=StartUpdate area w;
		strict1=update (strict2) s;
     # (s`, dfs) = strict1;
      io_state``= UEvaluate_2 io_state` (Draw_in_window window offset dfs);
	=
		EndUpdate (s`, io_state``) w;
WindowIO` window_att_event=:(w,XWindowActivate,e`) s io_state
   #!
		io_state``=io_state``;
	=
		WindowAttIO window_att_event window_att s io_state``;
      where {
      io_state``=: SetActiveWindowHandle w io_state`;
      window_att=: GetWindowAttributes w windows;
      (windows,io_state`)=: IOStateGetDevice io_state WindowDevice;
      };
WindowIO` window_att_event=:(w,e,e`) s io_state
   =  WindowAttIO window_att_event window_att s io_state`;
      where {
      window_att=: GetWindowAttributes w windows;
      (windows,io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

WindowAttIO :: !Event ![WindowAttribute *s (IOState *s)] !*s !(IOState *s)
   -> (!*s, !IOState *s);
WindowAttIO (w, XWindowKeyboard, e) [Keyboard a f : atts] s io
   | SelectStateEqual a Able =  f key_info s io;
   =  (s, io);
      where {
      key_info=: EventToKeyboard (get_key_state e);
      };
WindowAttIO (w, XWindowMouse, e) [Mouse a f : atts] s io
   | SelectStateEqual a Able =  f mouse_info s io;
   =  (s, io);
      where {
      mouse_info=: EventToMouse (get_mouse_state e);
      };
WindowAttIO (w, XWindowClosed,     e) [GoAway     f : atts] s io =  f s io;
WindowAttIO (w, XWindowActivate,   e) [Activate   f : atts] s io =  f s io;
WindowAttIO (w, XWindowDeactivate, e) [Deactivate f : atts] s io =  f s io;
WindowAttIO event [att : atts] s io
   =  WindowAttIO event atts s io;
WindowAttIO event atts s io =  (s, io);

EventToKeyboard :: !KeyEvent -> KeyboardState;
EventToKeyboard (key,m1,m2,m3,m4,XKeyUp)
   =  (toChar key, KeyUp,  (I2B m1, I2B m2, I2B m3, I2B m4));
EventToKeyboard (key,m1,m2,m3,m4,XKeyDown)
   =  (toChar key, KeyDown,  (I2B m1, I2B m2, I2B m3, I2B m4));
EventToKeyboard (key,m1,m2,m3,m4,XKeyStillDown)
   =  (toChar key, KeyStillDown,  (I2B m1, I2B m2, I2B m3, I2B m4));

EventToMouse :: !MouseEvent -> MouseState;
EventToMouse (x,y,XButtonUp,m1,m2,m3,m4)
   =  ((x,y),ButtonUp, (I2B m1, I2B m2, I2B m3, I2B m4));
EventToMouse (x,y,XButtonDown,m1,m2,m3,m4)
   =  ((x,y),ButtonDown, (I2B m1, I2B m2, I2B m3, I2B m4));
EventToMouse (x,y,XButtonStillDown,m1,m2,m3,m4)
   =  ((x,y),ButtonStillDown, (I2B m1, I2B m2, I2B m3, I2B m4)); 
EventToMouse (x,y,XDoubleClick,m1,m2,m3,m4)
   =  ((x,y),ButtonDoubleDown, (I2B m1, I2B m2, I2B m3, I2B m4));
EventToMouse (x,y,XTripleClick,m1,m2,m3,m4)
   =  ((x,y),ButtonTripleDown, (I2B m1, I2B m2, I2B m3, I2B m4));

I2B :: !Int -> Bool;
I2B 0 =  False;
I2B x =  True;


/* Hiding and showing the window device i.e. hiding and showing all windows.
*/
HideWindow :: !(IOState s) -> IOState s;
HideWindow io_state 
   =  IOStateSetDevice io_state` windows`;
      where {
      windows`            =: HideWindow` windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

HideWindow` :: !(DeviceSystemState s) -> DeviceSystemState s;
HideWindow` (WindowSystemState windows)
   #!
		strict1=strict1;
	=
		WindowSystemState strict1;
	where {
	strict1=(HideWindow`` windows);
		
	};

HideWindow`` :: !(WindowHandles s) -> WindowHandles s;
HideWindow`` [(w_def,(win,pic)) : windows]
   #!
		strict1=strict1;
		strict2=strict2;
	=
		[(w_def,(strict1,pic)) : strict2];
	where {
	strict1=popdown win;
		strict2=HideWindow`` windows;
		
	};
HideWindow`` windows =  windows;


ShowWindow :: !(IOState s) -> IOState s;
ShowWindow io_state
   =  IOStateSetDevice io_state` windows`;
      where {
      windows`            =: ShowWindow` windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

ShowWindow` :: !(DeviceSystemState s) -> DeviceSystemState s;
ShowWindow` (WindowSystemState windows)
   #!
		strict1=strict1;
	=
		WindowSystemState strict1;
	where {
	strict1=(ShowWindow`` windows);
		
	};

ShowWindow`` :: !(WindowHandles s) -> WindowHandles s;
ShowWindow`` [(w_def, (win,pic)) : windows]
   #!
		strict1=strict1;
		strict2=strict2;
	=
		[(w_def, (strict1,pic)) : strict2];
	where {
	strict1=popup win;
		strict2=ShowWindow`` windows;
		
	};
ShowWindow`` windows =  windows;


/* Internal window handling functions.
*/
SetWindowAttributes :: !Widget ![WindowAttribute s io ] -> Widget;
SetWindowAttributes window [Cursor shape : atts]
   =  SetWindowAttributes (SetWidgetCursor window shape) atts;
SetWindowAttributes window [att : atts] 
   =  SetWindowAttributes window atts;
SetWindowAttributes w atts =  w;

GetWindowDef :: !Widget ![WindowHandle s] -> WindowDef s (IOState s);
GetWindowDef w [(w_def,(w`,pic)) : windows]
   | w == w` =  w_def;
   =  GetWindowDef w windows;

GetWindowAttributes :: !Widget !(DeviceSystemState s)
   -> [WindowAttribute s (IOState s)];
GetWindowAttributes w (WindowSystemState windows)
   =  GetWindowAttributes` w windows;

GetWindowAttributes` :: !Widget !(WindowHandles s)
   -> [WindowAttribute s (IOState s)];
GetWindowAttributes` w [(w_def,(w`,pic)) : windows]
   | w == w` =  WindowDef_Attributes w_def;
   =  GetWindowAttributes` w windows;
GetWindowAttributes` w windows =  [];

GetWindowUpdateFunction :: !Widget !(DeviceSystemState s) -> UpdateFunction s;
GetWindowUpdateFunction w (WindowSystemState windows)
   =  GetWindowUpdateFunction` w windows;

GetWindowUpdateFunction` :: !Widget !(WindowHandles s)
   -> UpdateFunction s;
GetWindowUpdateFunction` w [(w_def,(w`,pic)) : windows]
   | w == w` =  WindowDef_Update w_def;
   =  GetWindowUpdateFunction` w windows;
GetWindowUpdateFunction` w windows =  NoUpdateFunc;

NoUpdateFunc :: UpdateArea * s -> (*s, [DrawFunction]);
NoUpdateFunc area s =  (s, []);

GetPictureOffset :: !Widget !(DeviceSystemState s) -> (!Int,!Int);
GetPictureOffset w (WindowSystemState windows) =  GetPictureOffset` w windows;

GetPictureOffset` :: !Widget !(WindowHandles s) -> (!Int,!Int);
GetPictureOffset` w [(w_def,(w`,pic)) : windows]
   | w == w` =  xy0;
   =  GetPictureOffset` w windows;
      where {
      (xy0,xy1)=: WindowDef_Domain w_def;
      };

GetWindowHandle :: !Widget !(DeviceSystemState s) -> Window;
GetWindowHandle w (WindowSystemState windows) =  GetWindowHandle` w windows;

GetWindowHandle` :: !Widget !(WindowHandles s) -> Window;
GetWindowHandle` w [(w_def,window=:(w`,pic)) : windows]
   | w == w` =  window;
   =  GetWindowHandle` w windows;

GetWindowHandleFromId :: !WindowId !(DeviceSystemState s) -> (!Bool, !Window);
GetWindowHandleFromId id (WindowSystemState windows)
   =  GetWindowHandleFromId` id windows;

GetWindowHandleFromId` :: !WindowId ![WindowHandle s] -> (!Bool, !Window);
GetWindowHandleFromId` id [(def,window) : windows]
   | id ==  WindowDef_WindowId def    =  (True, window);
   =  GetWindowHandleFromId` id windows;
GetWindowHandleFromId` id windows =  (False, (0, NewXPicture 0));

GetWindowHandleFromDevice :: !WindowId !(DeviceSystemState s)
   -> [WindowHandle s];
GetWindowHandleFromDevice id (WindowSystemState windows)
   =  GetWindowHandleFromDevice` id windows;

GetWindowHandleFromDevice` :: !WindowId !(WindowHandles s)
   -> WindowHandles s;
GetWindowHandleFromDevice` id [w=:(w_def,window) : windows]
   | id ==  WindowDef_WindowId w_def  =  [w];
   =  GetWindowHandleFromDevice` id windows;
GetWindowHandleFromDevice` id windows =  windows;

GetWindowHandleFromDeviceW :: !Widget (DeviceSystemState s)
   -> WindowHandles s;
GetWindowHandleFromDeviceW w (WindowSystemState windows)
   =  GetWindowHandleFromDeviceW` w windows;

GetWindowHandleFromDeviceW` :: !Widget !(WindowHandles s)
   -> WindowHandles s;
GetWindowHandleFromDeviceW` w [handle=:(w_def,(window,pic)) : windows]
   | w == window =  [handle];
   =  GetWindowHandleFromDeviceW` w windows;
GetWindowHandleFromDeviceW` w windows =  windows;

PutWindowHandleInDevice :: !WindowId ![WindowHandle s]
      !(DeviceSystemState s)
   -> DeviceSystemState s;
PutWindowHandleInDevice id [] device =  device;
PutWindowHandleInDevice id [new] (WindowSystemState windows)
   =  WindowSystemState (PutWindowHandleInDevice` id new windows);

PutWindowHandleInDevice` :: !WindowId !(WindowHandle s)
      !(WindowHandles s)
   -> WindowHandles s;
PutWindowHandleInDevice` id new [w=:(def,window) : windows]
   | id ==  WindowDef_WindowId def  =  [new : windows];
   =  [w : PutWindowHandleInDevice` id new windows];
PutWindowHandleInDevice` id new windows =  windows;

SetActiveWindowHandle :: !Widget !(IOState s) -> IOState s;
SetActiveWindowHandle w io
   =  IOStateSetDevice io` (SetActiveWindowHandle` w wh);
      where {
      (wh, io`)=: IOStateGetDevice io WindowDevice;
      };

SetActiveWindowHandle` :: !Widget !(DeviceSystemState s) -> DeviceSystemState s;
SetActiveWindowHandle` w (WindowSystemState windows)
   #!
		strict1=strict1;
		windows`=windows`;
	=
		WindowSystemState [strict1 : windows`];
      where {
      handle  =: GetWindowHandleFromDeviceW` w windows;
      windows`=: RemoveWindowHandle w windows;
      strict1=First handle;
		};

First :: ![x] -> x;
First [x : l] =  x;

RemoveWindowHandle :: !Widget !(WindowHandles s) 
   -> WindowHandles s;
RemoveWindowHandle w [window=:(w_def,(win,pic)) : windows]
   | win == w =  windows;
   #!
		strict1=strict1;
	=
		[window : strict1];
	where {
	strict1=RemoveWindowHandle w windows;
		
	};
RemoveWindowHandle w windows =  windows;

Align_thumb :: !Int !Int !Int !Int -> Int;
Align_thumb thumb min max scroll
	| thumb == max
		=  thumb;
		=  min + (d_thumb -  d_thumb rem scroll );
	where {
		d_thumb=: thumb - min;
	};

CollectUpdateArea :: !Widget -> UpdateArea;
CollectUpdateArea w 
	# (x,y,xx,yy,more) = get_expose_area w;
	| more==0
		= [];
    # rect = ((x,y),(xx,yy));
	| more == 1
		= [rect];
		#! t = CollectUpdateArea w;
		= [rect : t];

StartUpdate :: !UpdateArea !Widget -> UpdateArea;
StartUpdate u w =  Evaluate_2 u (start_update w);

EndUpdate :: !(!*s, !IOState *s) !Widget -> (!*s, !IOState *s);
EndUpdate s w =  UEvaluate_2 s (end_update w); 

Draw_in_window :: !Window !(!Int,!Int) ![DrawFunction] -> Window;
Draw_in_window window=:(0,pic) offset fs =  window;
Draw_in_window (win,pic) offset fs 
   =  (win, EndDrawing (Draw_in_picture (CreatePicture (StartDrawing pic)) fs));

Draw_in_picture :: !Picture ![DrawFunction] -> XPicture;
Draw_in_picture pic [f : fs] 
   =  Draw_in_picture (f pic) fs;
Draw_in_picture pic fs =  MakeXPicture pic;

ValidateWindow :: !(WindowDef s (IOState s)) -> (!Bool, !WindowDef s (IOState s));
ValidateWindow (ScrollWindow id pos =: ((left,top)) t hbar=: (ScrollBar (Thumb h_val) (Scroll h_scroll)) vbar=: (ScrollBar (Thumb v_val) (Scroll v_scroll)) pic =: (((h_min,v_min),(h_max,v_max))) ms  =: ((min_w,min_h)) is  =: ((init_w,init_h)) upd att)
	| h_min >= h_max   || v_min >= v_max || d_h  < 10   || d_v  < 10
		=  abort "Error while opening a window: illegal PictureDomain";
		=  (False,ScrollWindow id pos` t hbar` vbar` pic min_size` init_size` upd att);
      where {
      pos`      =: (Maximum 0 (Minimum left s_h),
                     Maximum 0 (Minimum top  s_v));
      hbar`     =: ScrollBar (Thumb h_val`) (Scroll h_scroll`);
      vbar`     =: ScrollBar (Thumb v_val`) (Scroll v_scroll`);
      h_val`    =: Maximum h_min (Minimum mod_h_val h_max`);
      h_max`    =: h_max - init_w`;
      v_val`    =: Maximum v_min (Minimum mod_v_val v_max`);
      v_max`    =: v_max - init_h`;
      mod_h_val =: Align_thumb h_val h_min h_max` h_scroll`;
      mod_v_val =: Align_thumb v_val v_min v_max` v_scroll`;
      min_size` =: (min_w``, min_h``);
      min_w`    =: Minimum min_w init_w`;
      min_h`    =: Minimum min_h init_h`;
      init_size`=: (init_w`, init_h`);
      d_h`      =: Minimum d_h s_h;
      d_v`      =: Minimum d_v s_v;
      d_h       =: h_max - h_min;
      d_v       =: v_max - v_min;
      h_scroll` =: Maximum 1 (Minimum h_scroll d_h);
      v_scroll` =: Maximum 1 (Minimum v_scroll d_v);
      s_h       =: s_r - 50;
      s_v       =: s_b - 50;
      (s_r, s_b)=: get_screen_size 0;
     min_w``=: Maximum min_w` 70;
                min_h``=: Maximum min_h` 70;
                init_w`=: Minimum init_w d_h`;
                init_h`=: Minimum init_h d_v`;
		};
ValidateWindow (FixedWindow id pos=: ((left,top)) title pic=: (((h_min,v_min),(h_max,v_max))) upd att)
   | h_min >= h_max   || v_min >= v_max
          =  abort "Error while opening a window: illegal PictureDomain"; 
   | width >= maxwidth || height >= maxheight
          =  (True,ScrollWindow id pos` title hbar vbar pic msize isize upd att);
   =  (False,FixedWindow id pos` title pic upd att);
      where {
      pos`      =: (Maximum 0 (Minimum left s_h),
                     Maximum 0 (Minimum top  s_v));
      hbar      =: ScrollBar (Thumb h_min) (Scroll 10);
      vbar      =: ScrollBar (Thumb v_min) (Scroll 10);
      isize     =: (newwidth,newheight); msize=: (100,100);
      newwidth  =: if (width >  maxwidth)  maxwidth  width;
      newheight =: if (height > maxheight) maxheight height; 
      s_h       =: s_r - 50; s_v=: s_b - 50;
      width     =: h_max - h_min; height=: v_max - v_min;
      maxwidth  =: s_r - 100; maxheight=: s_b - 100;
      (s_r, s_b)=: get_screen_size 0;
      };

WindowDef_WindowId :: !(WindowDef s io) -> WindowId;
WindowDef_WindowId (ScrollWindow id pos title sh sv pic msize isize upd att)
   =  id;
WindowDef_WindowId (FixedWindow id pos title pic upd att)
   =  id;

WindowDef_Position :: !(WindowDef s io) -> WindowPos;
WindowDef_Position (ScrollWindow id pos title sh sv pic msize isize upd att)
   =  pos;
WindowDef_Position (FixedWindow id pos title pic upd att)
   =  pos;

WindowDef_Domain :: !(WindowDef s io) -> PictureDomain;
WindowDef_Domain (ScrollWindow id pos title sh sv  pic msize isize upd att)
   =  pic ;
WindowDef_Domain (FixedWindow id pos title pic upd att)
   =  pic;

WindowDef_Title :: !(WindowDef s io) -> String;
WindowDef_Title (ScrollWindow id pos title sh sv pic msize isize upd att)
   =  title ;
WindowDef_Title (FixedWindow id pos title pic upd att)
   =  title;

WindowDef_ScrollBars :: !(WindowDef s io) -> (!ScrollBarDef, !ScrollBarDef);
WindowDef_ScrollBars (ScrollWindow id pos title sh sv pic msize isize upd att)
   =  (sh,sv);

WindowDef_MinimumWindowSize :: !(WindowDef s io) -> MinimumWindowSize;
WindowDef_MinimumWindowSize 
     (ScrollWindow id pos title sh sv pic msize isize upd att)
   =  msize;

WindowDef_InitialSize :: !(WindowDef s io) -> InitialWindowSize;
WindowDef_InitialSize (ScrollWindow id pos title sh sv pic msize isize upd att)
   =  isize;

WindowDef_Update :: !(WindowDef s io) -> UpdateFunction s;
WindowDef_Update (ScrollWindow id pos title sh sv pic msize isize upd att)
   =  upd;
WindowDef_Update (FixedWindow id pos title pic upd att)
   =  upd;

WindowDef_Attributes ::        !(WindowDef s io) -> [WindowAttribute s io];
WindowDef_Attributes (ScrollWindow id pos title sh sv pic msize isize upd att)
   =  att ;
WindowDef_Attributes (FixedWindow id pos title pic upd att)
   =  att;

WindowDef_SetTitle :: !(WindowDef s io) !WindowTitle -> WindowDef s io;
WindowDef_SetTitle 
     (ScrollWindow id pos title sh sv pic msize isize upd att) new_title
   =   ScrollWindow id pos new_title sh sv pic msize isize upd att;
WindowDef_SetTitle (FixedWindow id pos title pic upd att) new_title
   =  FixedWindow id pos new_title pic upd att;

WindowDef_SetUpdate :: !(WindowDef s io) !(UpdateFunction s) -> WindowDef s io;
WindowDef_SetUpdate 
     (ScrollWindow id pos title sh sv pic msize isize upd att) f_new
   =  ScrollWindow id pos title sh sv pic msize isize f_new att;
WindowDef_SetUpdate
     (FixedWindow id pos title pic upd att) f_new
   =  FixedWindow id pos title pic f_new att;

WindowDef_SetPictureDomain :: !(WindowDef s io) !PictureDomain -> WindowDef s io;
WindowDef_SetPictureDomain 
     (ScrollWindow id pos title sh sv pic msize isize upd att) newpic
   =  ScrollWindow id pos title sh sv newpic msize isize upd att;
WindowDef_SetPictureDomain
     (FixedWindow id pos title pic upd att) newpic
   =  FixedWindow id pos title newpic upd att;

WindowDef_SetAttributes :: !(WindowDef s io) ![WindowAttribute s io]
   -> WindowDef s io;
WindowDef_SetAttributes 
     (ScrollWindow id pos title sh sv pic msize isize upd att) newatt
   =  ScrollWindow id pos title sh sv pic msize isize upd newatt;
WindowDef_SetAttributes
     (FixedWindow id pos title pic upd att) newatt
   =  FixedWindow id pos title pic upd newatt;

