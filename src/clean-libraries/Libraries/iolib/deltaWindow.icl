implementation module deltaWindow;

import StdClass, StdMisc, StdInt, StdString, StdBool, ioState;
import windowDevice,cursorInternal;
import xwindow;
import misc;

Scrollable :== 0;
FixedSize  :== 1;

/* Opening windows: */
OpenWindows :: ![WindowDef s (IOState s)] !(IOState s) -> IOState s;
OpenWindows [] io_state =  io_state;
OpenWindows w_defs io_state
   =  IOStateSetDevice io_state` windows`;
      where {
      windows`            =: OpenWindows` w_defs windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

OpenWindows` :: ![WindowDef s (IOState s)] !(DeviceSystemState s) 
   -> DeviceSystemState s;
OpenWindows` w_defs (WindowSystemState windows)
   #!
		strict1=strict1;
		=
		WindowSystemState strict1;
	where {
	strict1=(Open_windows w_defs windows);		
	};

/* Closing windows: */
CloseWindows :: ![WindowId] !(IOState s) -> IOState s;
CloseWindows [] io_state =  io_state;
CloseWindows ids io_state
   =  IOStateSetDevice io_state` windows`;
      where {
      windows`            =: CloseWindows` ids windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };
        
CloseWindows` :: ![WindowId] !(DeviceSystemState s) -> DeviceSystemState s;
CloseWindows` ids (WindowSystemState windows)
   #!
		strict1=strict1;
		=
		WindowSystemState strict1;
	where {
	strict1=(Close_windows ids windows);
		
	};

Close_windows :: ![WindowId] !(WindowHandles s)
   -> WindowHandles s;
Close_windows [id : ids] windows
   =  Close_windows ids (Close_window` id windows);
Close_windows ids windows =  windows;

Close_window` :: !WindowId ![(WindowDef s (IOState s),Window)]
   -> [(WindowDef s (IOState s),Window)];
Close_window` id [w_and_h=:(w_def, window) : w_and_hs]
   | id <>  WindowDef_WindowId w_def  #!
		strict1=strict1;
		=
		[w_and_h : strict1];
   =  Evaluate_2 w_and_hs (Close_window window);
	where {
	strict1=Close_window` id w_and_hs;
		
	};
Close_window` id w_and_hs =  w_and_hs;
            
CloseActiveWindow :: !(IOState s) -> IOState s;
CloseActiveWindow io_state
   | active   =  CloseWindows [id] io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };


/* Retrieve the Id of the active window
*/
GetActiveWindow :: !(IOState s) -> (!Bool, !WindowId, !IOState s);
GetActiveWindow io_state
   | WindowDeviceNotEmpty windows =  (True, id, io_state`);
   =  (False, 0, io_state`);
      where {
      id=: WindowDef_WindowId (GetActiveWindowDef windows);
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

GetActiveWindowDef :: !(DeviceSystemState s) -> WindowDef s (IOState s);
GetActiveWindowDef (WindowSystemState [(def,win):windows]) =  def;

/* Activate a window */
ActivateWindow :: !WindowId !(IOState s) -> IOState s;
ActivateWindow id io_state
  | not exists
	=  io_state`;
// =  SetActiveWindowHandle (activate_window widget) io_state`;
	# r =  activate_window widget;
	| r==r
   		= io_state`;
  where {
      (widget,  pic      )=: window;
      (exists,  window   )=: GetWindowHandleFromId id windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
  };

/* Changing UpdateFunctions
*/
ChangeUpdateFunction :: !WindowId !(UpdateFunction s) !(IOState s) -> IOState s;
ChangeUpdateFunction id f io_state
   | WindowDeviceNotEmpty windows =  IOStateSetDevice io_state` windows`;
   =  io_state`;
      where {
      windows`            =: ChangeUpdateFunction` id f windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

ChangeUpdateFunction` :: !WindowId !(UpdateFunction s) !(DeviceSystemState s)
   -> DeviceSystemState s;
ChangeUpdateFunction` id f (WindowSystemState windows)
   #!
		strict1=strict1;
		=
		WindowSystemState strict1;
	where {
	strict1=(ChangeUpdateFunction`` id f windows);
		
	};

ChangeUpdateFunction`` :: !WindowId !(UpdateFunction s) !(WindowHandles s)
   -> WindowHandles s;
ChangeUpdateFunction`` id new_f [window=:(w_def,win) : windows]
   | id == id` #!
		strict1=strict1;
		=
		[(strict1, win) : windows];
   #!
		strict2=strict2;
		=
		[window : strict2];
      where {
      id`=: WindowDef_WindowId w_def;
      strict2=ChangeUpdateFunction`` id new_f windows;
		strict1=WindowDef_SetUpdate w_def new_f;
		};
ChangeUpdateFunction`` id new_f windows =  windows;

ChangeActiveUpdateFunction :: !(UpdateFunction s) !(IOState s) -> IOState s;
ChangeActiveUpdateFunction f io_state
   | active =  ChangeUpdateFunction id f io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };
     

/* Change window titles
*/
ChangeWindowTitle :: !WindowId !WindowTitle !(IOState s) -> IOState s;
ChangeWindowTitle id title io_state
   | WindowDeviceNotEmpty windows =  IOStateSetDevice io_state` windows`;
   =  io_state`;
      where {
      windows`            =: ChangeWindowTitle` id title windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

ChangeWindowTitle` :: !WindowId !WindowTitle !(DeviceSystemState s)
   -> DeviceSystemState s;
ChangeWindowTitle` id title (WindowSystemState windows)
   #!
		strict1=strict1;
		=
		WindowSystemState strict1;
	where {
	strict1=(ChangeWindowTitle`` id title windows);
		
	};

ChangeWindowTitle`` :: !WindowId !WindowTitle !(WindowHandles s)
   -> WindowHandles s;
ChangeWindowTitle`` id title [window=:(w_def,win) : windows]
   | id == id`   #!
      w_def`      = WindowDef_SetTitle w_def title;
   #  (w_ptr, pic)= win;
   #!	strict2=set_window_title w_ptr title;
   #  win`        = (strict2, pic);
		=
		 [(w_def`, win`) : windows];
   #!
      strict1=ChangeWindowTitle`` id title windows;
		=
		[window : strict1];
      where {
      id`         =: WindowDef_WindowId w_def;
		};
ChangeWindowTitle`` id title windows =  windows;

ChangeActiveWindowTitle :: !WindowTitle !(IOState s) -> IOState s;
ChangeActiveWindowTitle title io_state
   | active   =  ChangeWindowTitle id title io_state`;
   =  io_state`;
      where {
      (active,id,io_state`)=: GetActiveWindow io_state;
      };


/* Change scrollbar settings
*/

    

:: ScrollBarChange
    =  ChangeThumbs  Int Int   // set new horizontal and vertical thumb values
    |   ChangeScrolls Int Int   // set new horizontal and vertical scroll values
    |   ChangeHThumb  Int       // set new horizontal thumb value
    |   ChangeVThumb  Int       // set new vertical thumb value
    |   ChangeHScroll Int       // set new horizontal scroll value
    |   ChangeVScroll Int       // set new vertical scroll value
    |   ChangeHBar    Int Int   // set new horizontal thumb and scroll values
    |   ChangeVBar    Int Int;  // set new vertical thumb and scroll values


    

ChangeScrollBar :: !WindowId !ScrollBarChange !*s !(IOState *s) -> (!*s, !IOState *s);
ChangeScrollBar id change s io_state
   | WindowDeviceNotEmpty windows =  (s`, IOStateSetDevice io_state` windows`);
   =  (s`, io_state`);
      where {
      windows`            =: PutWindowHandleInDevice id window` windows;
      (s`, window`)       =: ChangeScrollBar` s window change;
      window              =: GetWindowHandleFromDevice id windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

ChangeActiveScrollBar :: !ScrollBarChange !*s !(IOState *s) -> (!*s, !IOState *s);
ChangeActiveScrollBar change s io_state
   | active =  ChangeScrollBar id change s io_state`;
   =  (s, io_state`);
      where {
      (active,id,io_state`)=: GetActiveWindow io_state;
      };

ChangeScrollBar` :: !*s !(WindowHandles *s) !ScrollBarChange
   -> (!*s, !WindowHandles *s);
ChangeScrollBar` s [scroll_window=: ((ScrollWindow i p t h v pd ms is up att, window))] change| OnlyThumbsChange change =  (s1, [window1]);
   | OnlyScrollsChange change =  (s2, [window2]);
   =  (s3, [window3]);
      where {
      (s1, window1)=: Change_thumbs  s scroll_window change;
      (s2, window2)=: Change_scrolls s scroll_window change;
      (s3, window3)=: Change_bar     s scroll_window change;
      };
ChangeScrollBar` s windows change =  (s, []);

Change_thumbs :: !*s !(WindowHandle *s) !ScrollBarChange
   -> (!*s, !WindowHandle *s);
Change_thumbs s (ScrollWindow i p t h =: (ScrollBar (Thumb old_h) s_h=:(Scroll h_scroll)) v =: (ScrollBar (Thumb old_v) s_v=:(Scroll v_scroll)) pd=: (((h_min,v_min),(h_max,v_max))) ms is up att,(win,pic)) change| ThumbsChange change 
	#! h`  = ScrollBar (Thumb new_h) s_h;
	   v`  = ScrollBar (Thumb new_v) s_v;
	# (s1,win1)= ScrUpd s up pic 
                        (set_scrollbars win h_min v_min new_h (-1) new_v (-1));
	#! win1=win1;
		=
		(s1,(ScrollWindow i p t h` v` pd ms is up att, (win1,pic)));
   | HThumbChange change
	#! h`     = ScrollBar (Thumb new_h) s_h;
	#  (s2,win2)= ScrUpd s up pic
                        (set_scrollbars win h_min v_min new_h (-1) (-1) (-1));
	#!	win2=win2;
		=
		(s2,(ScrollWindow i p t h` v pd ms is up att, (win2,pic)));
	#! v`     = ScrollBar (Thumb new_v) s_v;
	#  (s3,win3)= ScrUpd s up pic
                        (set_scrollbars win h_min v_min (-1) (-1) new_v (-1));
	#! win3=win3;
		=
		(s3,(ScrollWindow i p t h v` pd ms is up att, (win3,pic)));
      where {
      new_h  =: Maximum h_min (Minimum mh_val h_max`);
      new_v  =: Maximum v_min (Minimum mv_val v_max`);
      mh_val =: Align_thumb h_val h_min h_max` h_scroll;
      mv_val =: Align_thumb v_val v_min v_max` v_scroll;
      (h_val,v_val)=: ChangeValues change;
      (w,he)  =: get_window_size win;
      h_max`=:(h_max - w);
                v_max`=:(v_max - he);
		};

ScrUpd :: !*s !(UpdateFunction *s) !XPicture !(!Widget, !Int) -> (!*s, !Widget);
ScrUpd s upd p (w,0) =  (s,w);
ScrUpd s upd p (w,n)
   #!
      area     = CollectUpdateArea w;
   #! strict2=(StartUpdate area w);
   #  (s`, dfs)= upd strict2 s;
   #! strict1=Draw_in_window (w,p) (0,0) dfs;
   # 
      (w`, p` )= strict1;
		=
		(s`, end_update w`);

Change_scrolls :: !*s !(WindowHandle *s) !ScrollBarChange
   -> (!*s, !WindowHandle *s);
Change_scrolls s (ScrollWindow i p t h =: (ScrollBar t_h=:(Thumb old_h) s_h=:(Scroll h_scroll)) v =: (ScrollBar t_v=:(Thumb old_v) s_v=:(Scroll v_scroll)) pd=: (((h_min,v_min),(h_max,v_max))) ms is up att,(win,pic)) change| ScrollsChange change #!
      h`     = Evaluate_2 (ScrollBar t_h (Scroll new_h_s))
                          (set_scrollbars win h_min v_min (-1) new_h_s (-1) (-1));
      v`     = Evaluate_2 (ScrollBar t_v (Scroll new_v_s))
                          (set_scrollbars win h_min v_min (-1) (-1) (-1) new_v_s);
		=
		Change_thumbs s (ScrollWindow i p t h` v` pd ms is up att,(win,pic))
                    (ChangeThumbs new_h_t new_v_t);
   | HScrollChange change #!
      h`     = Evaluate_2 (ScrollBar t_h (Scroll new_h_s))
                          (set_scrollbars win h_min v_min (-1) new_h_s (-1) (-1));
		v=v;
		=
		Change_thumbs s (ScrollWindow i p t h` v pd ms is up att, (win,pic))
                    (ChangeHThumb new_h_t);
   #!
		h=h;
      v`     = Evaluate_2 (ScrollBar t_v (Scroll new_v_s))
                          (set_scrollbars win h_min v_min (-1) (-1) (-1) new_v_s);
		=
		Change_thumbs s (ScrollWindow i p t h v` pd ms is up att, (win,pic))
                    (ChangeVThumb new_v_t);
      where {
      new_h_s=: Maximum 1 (Minimum h_s (h_max - h_min));
      new_v_s=: Maximum 1 (Minimum v_s (v_max - v_min));
      new_h_t=: Maximum h_min (Minimum mod_h_t h_max`);
      new_v_t=: Maximum v_min (Minimum mod_v_t v_max`);
      mod_h_t=: Align_thumb old_h h_min h_max` h_s;
      mod_v_t=: Align_thumb old_v v_min v_max` v_s;
      (h_s,v_s)=: ChangeValues change;
      (w,he)  =: get_window_size win;
      h_max`=:(h_max - w);
                v_max`=:(v_max - he);
		};

Change_bar :: !*s !(WindowHandle *s) !ScrollBarChange
   -> (!*s, !WindowHandle *s);
Change_bar s window (ChangeHBar thumb scroll)
   #!
      strict1=Change_scrolls s window (ChangeHScroll scroll);
   #   (s`,window`)= strict1;
		=
		Change_thumbs s` window` (ChangeHThumb thumb);
Change_bar s window (ChangeVBar thumb scroll)
   #!
      strict1=Change_scrolls s window (ChangeVScroll scroll);
   #  (s`,window`)= strict1;
		=
		Change_thumbs s` window` (ChangeVThumb thumb);

OnlyThumbsChange :: !ScrollBarChange   -> Bool;
OnlyThumbsChange (ChangeThumbs h v) =  True;
OnlyThumbsChange (ChangeHThumb h)   =  True;
OnlyThumbsChange (ChangeVThumb v)   =  True;
OnlyThumbsChange change             =  False;

OnlyScrollsChange :: !ScrollBarChange    -> Bool;
OnlyScrollsChange (ChangeScrolls h v) =  True;
OnlyScrollsChange (ChangeHScroll h)   =  True;
OnlyScrollsChange (ChangeVScroll v)   =  True;
OnlyScrollsChange change              =  False;

ThumbsChange :: !ScrollBarChange   -> Bool;
ThumbsChange (ChangeThumbs h v) =  True;
ThumbsChange change             =  False;

HThumbChange :: !ScrollBarChange -> Bool;
HThumbChange (ChangeHThumb h) =  True;
HThumbChange change           =  False;

ScrollsChange :: !ScrollBarChange    -> Bool;
ScrollsChange (ChangeScrolls h v) =  True;
ScrollsChange change              =  False;

HScrollChange :: !ScrollBarChange  -> Bool;
HScrollChange (ChangeHScroll h) =  True;
HScrollChange change            =  False;

ChangeValues :: !ScrollBarChange    -> (!Int,!Int);
ChangeValues (ChangeThumbs h v)  =  (h,v);
ChangeValues (ChangeHThumb h)    =  (h,-1);
ChangeValues (ChangeHScroll h)   =  (h,-1);
ChangeValues (ChangeScrolls h v) =  (h,v);
ChangeValues (ChangeVThumb v)    =  (-1,v);
ChangeValues (ChangeVScroll v)   =  (-1,v);
ChangeValues (ChangeHBar t s)    =  (t,s);
ChangeValues (ChangeVBar t s)    =  (t,s);


/* Change Picture domain
*/
ChangePictureDomain :: !WindowId !PictureDomain !*s !(IOState *s) -> (!*s, !IOState *s);
ChangePictureDomain id domain s io_state
   | WindowDeviceNotEmpty windows =  (s`, IOStateSetDevice io_state` windows`);
   =  (s,  io_state`);
      where {
      (s`, windows`)      =: ChangePictureDomain` id domain s windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

ChangeActivePictureDomain :: !PictureDomain !*s !(IOState *s) -> (!*s, !IOState *s);
ChangeActivePictureDomain pd s io_state
   | active =  ChangePictureDomain id pd s io_state`;
   =  (s, io_state`);
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

ChangePictureDomain` :: !WindowId !PictureDomain !*s !(DeviceSystemState *s)
   -> (!*s, !DeviceSystemState *s);
ChangePictureDomain` id domain s (WindowSystemState windows=:[act=: ((def, (win,pic))) : rest])=  (s`, WindowSystemState windows`);
      where {
      (s`, windows`)=: ChangePictureDomain`` win id domain s windows;
      };

ChangePictureDomain`` :: !Widget !WindowId !PictureDomain !*s 
      !(WindowHandles *s)
   -> (!*s, !WindowHandles *s);
ChangePictureDomain`` act id npd s [window=:(def, win) : windows]
   | id ==  WindowDef_WindowId def  =  (s` , [window` : windows ]);
   =  (s``, [window  : windows`]);
      where {
      (s``, windows`)=: ChangePictureDomain``  act id npd s windows;
      (s`,  window` )=: ChangePictureDomain``` act    npd s window;
      };
ChangePictureDomain`` act id domain s windows =  (s, windows);

ChangePictureDomain``` :: !Widget !PictureDomain !*s !(WindowHandle *s)
   -> (!*s, !WindowHandle *s);
ChangePictureDomain``` act pd state (olddef, (win,pic))
   | changed #!
      strict1=(WindowDef_Update def``);
   #  (state``, win``)= ScrUpd state strict1 
                               newpic (get_first_update newwin);
		=
	 (state``, (def``, (win``, newpic)));
		=
		(state` , (def` , (win` , pic)));
      where {
      (newwin, newpic)  =: newwindow;
      (def``, newwindow)=: ReOpen_window act win def`;
      (changed, def`)   =: ValidateWindow (WindowDef_SetPictureDomain def pd);
      def               =: GetCurrentWindowdef win olddef;
      (state`, win`)    =: CorrectUpdates state win pic def def`;
		};

GetCurrentWindowdef :: !WindowPtr !(WindowDef s (IOState s))
   -> WindowDef s (IOState s);
GetCurrentWindowdef window olddef   =: (ScrollWindow i p t ohscrollb=: (ScrollBar (Thumb ohthumb) (Scroll hscroll)) ovscrollb=: (ScrollBar (Thumb ovthumb) (Scroll vscroll)) oldpd msize is u oa)#!
      newsize  = get_window_size window;
      strict1=get_current_thumbs window;
    # (hthumb,vthumb)= strict1;
      nhscrollb= ScrollBar (Thumb hthumb) (Scroll hscroll);
      nvscrollb= ScrollBar (Thumb vthumb) (Scroll hscroll);
		=
		ScrollWindow i p t nhscrollb nvscrollb oldpd msize newsize u oa;
GetCurrentWindowdef window def =  def;
     
CorrectUpdates :: !*s !WindowPtr !XPicture !(WindowDef *s (IOState *s))
      !(WindowDef *s (IOState *s))
   -> (!*s, !WindowPtr);
CorrectUpdates state window pic olddef   =: (ScrollWindow i p t ohscrollb=: (ScrollBar (Thumb ohthumb) (Scroll ohscroll)) ovscrollb=: (ScrollBar (Thumb ovthumb) (Scroll ovscroll)) oldpd oms oldsize  =: ((old_width, old_height)) u oa) newdef   =: (ScrollWindow ni np nt nhscrollb=: (ScrollBar (Thumb nhthumb) (Scroll nhscroll)) nvscrollb=: (ScrollBar (Thumb nvthumb) (Scroll nvscroll))
                              newpd    =: (((x0,y0),(x1,y1))) nms      =: ((min_width, min_height)) newsize  =: ((new_width, new_height)) upd na)| old_width <> new_width
                                                 || old_height <> new_height   #!
		changed_window=changed_window;
		= (s`,    discard_updates window`       );
   | ohthumb <> nhthumb
                                                 || ovthumb <> nvthumb   #!
		changed_window=changed_window;
		= (s``,   discard_updates window``      );
   #!
		changed_window=changed_window;
		=
		(state, discard_updates changed_window);
      where {
      (s`, upds)    =: upd [((nhthumb,nvthumb), 
                           (nhthumb + new_width, nvthumb + new_height))] state;
      (window`,pic`)=: Draw_in_window (changed_window,pic) (nhthumb,nvthumb) upds;
      (s``, upds`)  =: upd thumb_areas state;
      (window``,
        pic``)      =: Draw_in_window (changed_window,pic) (nhthumb,nvthumb) upds`;
      thumb_areas   =: ThumbUpdateAreas ohthumb nhthumb ovthumb nvthumb
                                       new_width new_height;
      changed_window=: change_window Scrollable window nhthumb nhscroll
                         nvthumb nvscroll new_width new_height
                         min_width min_height x0 y0 x1 y1;
       };
CorrectUpdates state window pic olddef   =: (FixedWindow i p t oldpd    =: (((oldx0,oldy0),(oldx1,oldy1))) u oa) newdef   =: (FixedWindow ni np nt newpd    =: (((x0,y0),(x1,y1))) upd na)| old_width <> new_width
                                     || old_height <> new_height =  (s`, discard_updates window`);
   #!
		strict1=strict1;
		=
		(state, window);
      where {
      (s`, upds)     =: upd [newpd] state;
      (window`, pic`)=: Draw_in_window strict1 (x0,y0) upds;
      changed_window =: change_window FixedSize window x0 0 y0 0
                                     new_width new_height 0 0 x0 y0 x1 y1;
      old_width      =: oldx1 - oldx0;    old_height=: oldy1 - oldy0;
      new_width      =: x1 - x0;          new_height=: y1 - y0;
      strict1=(changed_window,pic);
		};

ThumbUpdateAreas :: !Int !Int !Int !Int !Int !Int -> UpdateArea;
ThumbUpdateAreas ohthumb nhthumb ovthumb nvthumb width height
   =  Concat hareas vareas;
      where {
      hareas=: HThumbUpdateArea ohthumb nhthumb width height;
      vareas=: VThumbUpdateArea ovthumb ohthumb width height;
      };

HThumbUpdateArea :: !Int !Int !Int !Int -> UpdateArea;
HThumbUpdateArea oh nh width height
   | nh == oh =  [];
   |  nh - oh  > 0 =  [((oh + width, 0),(nh + width, height))];
   =  [((nh, 0),(oh,height))];

VThumbUpdateArea :: !Int !Int !Int !Int -> UpdateArea;
VThumbUpdateArea ov nv width height
   | nv == ov =  [];
   |  nv - ov  > 0 =  [((0, ov + height),(width, nv + height))];
   =  [((0, nv),(width, ov))];


/*  Drawing in windows:
*/
DrawInWindow :: !WindowId ![DrawFunction] !(IOState s) -> IOState s;
DrawInWindow id dfs io_state
   | exists   #!
      strict1=(Draw_in_window window offset dfs);
   #  windows` = Evaluate_2 windows strict1;
		=
		 IOStateSetDevice io_state` windows`;
		=
		io_state`;
      where {
      offset   =: GetPictureOffset win windows;
      (win,pic)=: window;
      (exists,  window)   =: GetWindowHandleFromId id windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
		};

DrawInActiveWindow :: ![DrawFunction] !(IOState s) -> IOState s;
DrawInActiveWindow dfs io_state 
   | active =  DrawInWindow id dfs io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

DrawInWindowFrame :: !WindowId !(UpdateFunction *s) !*s !(IOState *s) -> (!*s, !IOState *s);
DrawInWindowFrame id upd s io_state
   =  (s`, DrawInWindow id dfs io_state`);
      where {
      (s`, dfs)         =: upd [frame] s;
      (frame, io_state`)=: WindowGetFrame id io_state;
      };

DrawInActiveWindowFrame :: !(UpdateFunction *s) !*s !(IOState *s) -> (!*s, !IOState *s);
DrawInActiveWindowFrame upd s io_state 
   | active =  DrawInWindowFrame id upd s io_state`;
   =  (s, io_state`);
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };


/* Retrieving the current view on a picture i.e. the 'visible'
   part of the window.
*/
WindowGetFrame :: !WindowId !(IOState s) -> (!PictureDomain, !IOState s);
WindowGetFrame id io_state
   | not exists
   	= (((0,0),(0,0)), io_state`);
   #!
		x0=x0;
		y0=y0;
		strict3=strict3;
		strict4=strict4;
		=
		(((x0, y0),(strict3, strict4)), io_state`);
      where {
      (x0, y0)           =: get_current_thumbs widget;
      (w, h)             =: get_window_size widget;
      (widget, pic)      =: window;
      (exists, window)   =: GetWindowHandleFromId id device;
      (device, io_state`)=: IOStateGetDevice io_state WindowDevice;
      strict3=x0 + w;
		strict4=y0 + h;
		};

WindowGetPos :: !WindowId !(IOState s) -> (!Point,!IOState s);
WindowGetPos id io_state
	# (device,io_state) = IOStateGetDevice io_state WindowDevice;
	# (exists,window) = GetWindowHandleFromId id device;
	| not exists
		= ((0,0),io_state);
		# (widget,pic) = window;
		# (x,y) = get_window_position widget;
		= ((x,y),io_state);

ActiveWindowGetFrame :: !(IOState s) -> (!PictureDomain, !IOState s);
ActiveWindowGetFrame io_state
   | active =  WindowGetFrame id io_state`;
   =  (((0,0),(0,0)),io_state`);
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };


/* Enabling, disabling and changing the function of a Keyboard
*/

:: ChangeAttribute *s *io :== (WindowAttribute s io) -> (Bool, WindowAttribute s io);

EnableKeyboard :: !WindowId !(IOState s) -> IOState s;
EnableKeyboard id io_state
   =  ChangeWindowAttribute id (ChangeKeyboardAbility Able) io_state;

DisableKeyboard :: !WindowId !(IOState s) -> IOState s;
DisableKeyboard id io_state
   =  ChangeWindowAttribute id (ChangeKeyboardAbility Unable) io_state;

EnableActiveKeyboard :: !(IOState s) -> IOState s;
EnableActiveKeyboard io_state 
   | active =  EnableKeyboard id io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

DisableActiveKeyboard :: !(IOState s) -> IOState s;
DisableActiveKeyboard io_state 
   | active =  DisableKeyboard id io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

ChangeKeyboardAbility :: !SelectState !(WindowAttribute s (IOState s))
   -> (!Bool, !WindowAttribute s (IOState s));
ChangeKeyboardAbility state (Keyboard state` f) =  (True, Keyboard state f);
ChangeKeyboardAbility state attribute =  (False, attribute);


ChangeKeyboardFunction :: !WindowId !(KeyboardFunction s (IOState s)) !(IOState s)
   -> IOState s;
ChangeKeyboardFunction id f io_state
   =  ChangeWindowAttribute id (ChangeKeyboardFunction` f) io_state;

ChangeActiveKeyboardFunction :: !(KeyboardFunction s (IOState s)) !(IOState s)
   -> IOState s;
ChangeActiveKeyboardFunction f io_state
   | active =  ChangeKeyboardFunction id f io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

ChangeKeyboardFunction` :: !(KeyboardFunction s (IOState s))
      !(WindowAttribute s (IOState s))
   -> (!Bool, !WindowAttribute s (IOState s));
ChangeKeyboardFunction` f (Keyboard state f`) =  (True, Keyboard state f);
ChangeKeyboardFunction` f attribute =  (False, attribute);


/* Enabling, disabling and changing the function of a Mouse.
*/

EnableMouse :: !WindowId !(IOState s) -> IOState s;
EnableMouse id io_state
   =  ChangeWindowAttribute id (ChangeMouseAbility Able) io_state;

DisableMouse :: !WindowId !(IOState s) -> IOState s;
DisableMouse id io_state
   =  ChangeWindowAttribute id (ChangeMouseAbility Unable) io_state;

EnableActiveMouse :: !(IOState s) -> IOState s;
EnableActiveMouse io_state 
   | active =  EnableMouse id io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

DisableActiveMouse :: !(IOState s) -> IOState s;
DisableActiveMouse io_state 
   | active =  DisableMouse id io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

ChangeMouseAbility :: !SelectState !(WindowAttribute s (IOState s))
   -> (!Bool, !WindowAttribute s (IOState s));
ChangeMouseAbility state (Mouse state` f) =  (True, Mouse state f);
ChangeMouseAbility state attribute =  (False, attribute);


ChangeMouseFunction :: !WindowId !(MouseFunction s (IOState s)) !(IOState s)
   -> IOState s;
ChangeMouseFunction id f io_state
   =  ChangeWindowAttribute id (ChangeMouseFunction` f) io_state;

ChangeActiveMouseFunction :: !(MouseFunction s (IOState s)) !(IOState s)
   -> IOState s;
ChangeActiveMouseFunction f io_state
   | active =  ChangeMouseFunction id f io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

ChangeMouseFunction` :: !(MouseFunction s (IOState s))
      !(WindowAttribute s (IOState s))
   -> (!Bool, !WindowAttribute s (IOState s));
ChangeMouseFunction` f (Mouse state f`) =  (True, Mouse state f);
ChangeMouseFunction` f attribute =  (False, attribute);


ChangeWindowAttribute :: !WindowId !(ChangeAttribute *s (IOState *s)) !(IOState *s)
   -> IOState *s;
ChangeWindowAttribute id f io_state
   | WindowDeviceNotEmpty windows =  IOStateSetDevice io_state` windows`;
   =  io_state`;
      where {
      windows`            =: ChangeWindowAttribute` id f windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

ChangeWindowAttribute` :: !WindowId !(ChangeAttribute *s (IOState *s))
      !(DeviceSystemState *s)
   -> DeviceSystemState *s;
ChangeWindowAttribute` id f (WindowSystemState windows)
   #!
		strict1=strict1;
		=
		WindowSystemState strict1;
	where {
	strict1=(ChangeWindowAttribute`` id f windows);
		
	};

ChangeWindowAttribute`` :: !WindowId !(ChangeAttribute *s (IOState *s))
      !(WindowHandles *s)
   -> WindowHandles *s;
ChangeWindowAttribute`` id f [window=:(w_def,win) : windows]
   | id ==  WindowDef_WindowId w_def    #!
		w_def`=w_def`;
		strict2=strict2;
		=
		[(w_def`, win) : windows];
   #!
		w_def`=w_def`;
		strict2=strict2;
		=
		[window : strict2];
      where {
      w_def`=: WindowDef_SetAttributes w_def atts`;
      atts` =: ChangeAttributes f (WindowDef_Attributes w_def);
      strict2=ChangeWindowAttribute`` id f windows;
		};
ChangeWindowAttribute`` id f windows =  windows;

ChangeAttributes :: !(ChangeAttribute *s (IOState *s)) ![WindowAttribute *s (IOState *s)]
   -> [WindowAttribute *s (IOState *s)];
ChangeAttributes f [att : atts]
   	| fits=  [att` : atts];
   #!
		strict1=strict1;
		=
		[att  : strict1];
      where {
      (fits, att`)=: f att;
      strict1=ChangeAttributes f atts;
		};
ChangeAttributes f atts =  atts;


/*	Changing the cursor of a window.
*/
ChangeWindowCursor :: !WindowId !CursorShape !(IOState s) -> IOState s;
ChangeWindowCursor id change io_state
   | WindowDeviceNotEmpty windows =  IOStateSetDevice io_state` windows`;
   =  io_state`;
      where {
      windows`            =: ChangeWindowCursor` id change windows;
      (windows, io_state`)=: IOStateGetDevice io_state WindowDevice;
      };

ChangeActiveWindowCursor :: !CursorShape !(IOState s) -> IOState s;
ChangeActiveWindowCursor shape io_state
   | active =  ChangeWindowCursor id shape io_state`;
   =  io_state`;
      where {
      (active, id, io_state`)=: GetActiveWindow io_state;
      };

ChangeWindowCursor` :: !WindowId !CursorShape !(DeviceSystemState s)
   -> DeviceSystemState s;
ChangeWindowCursor` id change (WindowSystemState windows)
   #!
		strict1=strict1;
		=
		WindowSystemState strict1;
	where {
	strict1=(ChangeWindowCursor`` id change windows);
		
	};

ChangeWindowCursor`` :: !WindowId !CursorShape !(WindowHandles s)
   -> WindowHandles s;
ChangeWindowCursor`` id change [window=:(w_def,(win,pic)) : windows]
   | id ==  WindowDef_WindowId w_def    #!
		w_def`=w_def`;
		win`=win`;
		=
		[(w_def`, (win`,pic)) : windows];
   #!
		strict3=strict3;
		=
		[window : strict3];
      where {
      win`  =: SetWidgetCursor win change;
      w_def`=: WindowDef_SetAttributes w_def atts`;
      atts` =: ChangeWindowCursor``` change (WindowDef_Attributes w_def);
      strict3=ChangeWindowCursor`` id change windows;
		};
ChangeWindowCursor`` id change windows =  windows;

ChangeWindowCursor``` :: !CursorShape ![WindowAttribute s (IOState s)]
   -> [WindowAttribute s (IOState s)];
ChangeWindowCursor``` shape [Cursor oldshape : atts]
   =  [Cursor shape : atts];
ChangeWindowCursor``` shape [no_cursor : atts]
   #!
		strict1=strict1;
		=
		[no_cursor : strict1];
	where {
	strict1=ChangeWindowCursor``` shape atts;
		
	};
ChangeWindowCursor``` shape atts =  [Cursor shape];

