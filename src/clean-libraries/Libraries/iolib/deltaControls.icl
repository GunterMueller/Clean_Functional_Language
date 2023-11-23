implementation module deltaControls;

/*	The Controls implemented in this module can be used in dialogs.
	Currently scrolling lists and slider bars have been implemented.
*/

import StdClass, StdArray;
import StdInt,StdString,StdChar, StdBool, StdMisc;
import deltaDialog, deltaEventIO, deltaTimer, deltaFont, deltaPicture, deltaSystem;

/* General Scrolling List implementation. */

    
::	NrVisible  		:== Int;

     
	ChangeI			:== 0;
	NrVisI			:== 1;
	WidthI			:== 2;
	FirstI			:== 4;
	DefltI			:== 6;
	FirstItemIndex	:== 8;
	ItemWid wid		:== wid - 13;
	DownTop nr ht	:==  DownBot nr ht  - ArrowHgt;
	DownBot nr ht	:== nr * ht;
	UpTop				:== 0;
	UpBot				:== ArrowHgt;
	ArrowHgt			:== 17;
	NoAction			:== '0';
	Selected			:== '1';
	ScrolledUp		:== '2';
	ScrolledDown	:== '3';
	EndOfList		:== '\\';
	Error rule mes id
	:== abort ("Error in " +++  rule +++  " [deltaControls]: " +++  
		          mes +++  " (item id = " +++   toString id  +++ ")."     );

    

//
//	The ScrollingList item definition.
//

ScrollingList	:: !DialogItemId !ItemPos !Measure !SelectState !NrVisible !ItemTitle ![ItemTitle]
	              !(DialogFunction s (IOState s)) -> DialogItem s (IOState s);
ScrollingList id pos minwid abty nrvis defit items dfunc
	=  Control id pos ((-1,-1),(wid,hgt)) abty cstate (ScrollLook font wid at_new lnht)
		        (ScrollFeel wid at_new lnht) (ScrollDFunc id dfunc);
		where {
		cstate				=: StringCS (SetWidth wid state);
		(maxwid,state)		=: InitScrollState font nrvis defit items;
		wid					=:  max (MeasureToHorPixels minwid) maxwid  + 20;
		hgt					=: inc (nrvis * lnht);
		lnht					=: at_new + (dt + ld);
		(at_new,dt,mw,ld)		=: FontMetrics font;
		(b,font)				=: SelectFont name style size;
		(name,style,size)	=: DefaultFont;
		};

/*	The initial ControlState. */

InitScrollState	:: !Font !Int !ItemTitle ![ItemTitle] -> (!Int, !String);
InitScrollState font nrvis defit items =  (maxwid,state`);
		where {
		state`			=: SetNewFirst (nrvis - realnrvis) first state;
		(maxwid,state)	=: CreateScrollState font nrvis "" 0 False FirstItemIndex defit items;
		realnrvis		=: NrItemsVisible nrvis 0 first state;
		first				=: GetFirstIndex state;
		};

CreateScrollState	:: !Font !Int !String !Int !Bool !Int !ItemTitle ![ItemTitle]
	-> (!Int,!String);
CreateScrollState font nrvis state maxw found index defit [it : rest]
	| found || defit == it =  CreateScrollState font nrvis state` maxw` True index defit rest;
	=  CreateScrollState font nrvis state` maxw` found (index + len) defit rest;
		where {
		state`=: state +++  it +++ "\n" ;
		maxw`	=: max maxw (FontStringWidth it font);
		len	=: inc (size it);
		};
CreateScrollState font nrvis state maxw found index defit []
	| found =  (maxw, SetFirstIndex index (SetDefltIndex index state`));
	=  (maxw, SetFirstIndex FirstItemIndex (SetDefltIndex FirstItemIndex state`));
		where {
		state`=: (( toString Selected  +++  toString (toChar nrvis) ) +++ "      ") +++  state +++  toString EndOfList  ;
		};

NrItemsVisible	:: !Int !Int !Int !String -> Int;
NrItemsVisible nrvis nr index state
	| nrvis == 0 || no_more =  nr;
	=  NrItemsVisible (dec nrvis) (inc nr) index` state;
		where {
		(no_more,index`,it)=: GetItem index state;
		};

SetNewFirst	:: !Int !Int !String -> String;
SetNewFirst nr index state
	| nr <= 0 || no_more =  SetFirstIndex index state;
	=  SetNewFirst (dec nr) index` state;
		where {
		(no_more,index`,it)=: GetScrolledDownItem index state;
		};

/*	The ControlLook. */

ScrollLook	:: !Font !Int !Int !Int !SelectState !ControlState -> [DrawFunction];
ScrollLook font wid asct lnht abty (StringCS state)
	| able =  [frame,move,line,items : arrows];
	=  [frame,move,line,items : arrows];
		where {
		items	=: DrawItemTitles able nrvis asct lnht first wid defid state;
		arrows=: DrawArrows wid hgt abty state;
		frame	=: DrawRectangle ((-1,-1),(wid,hgt));
		move	=: MovePenTo (ItemWid wid, -1);
		line	=: LinePen (0, hgt);
		hgt	=: inc (nrvis * lnht);
		nrvis	=: GetNrVis state;
		first	=: GetFirstIndex state;
		defid	=: GetDefltIndex state;
		able=: Enabled abty;
		};

DrawArrows	:: !Int !Int !SelectState !String -> [DrawFunction];
DrawArrows wid hgt Able state
	| up && down =  [up1,up2,up3,down1,down2,down3];
	| down =  [up1,up2,up3];
	| up =  [down1,down2,down3];
	=  [];
		where {
		(up,down)=: CanScroll state;
		up1	=: FillPolygon up_arrow;
		up2	=: FillPolygon (MovePolygon (0,3) up_arrow);
		up3	=: FillPolygon (MovePolygon (0,9) up_arrow);
		down1	=: FillPolygon down_arrow;
		down2	=: FillPolygon (MovePolygon (0,-3) down_arrow);
		down3	=: FillPolygon (MovePolygon (0,-9) down_arrow);
		up_arrow=:((wid - 7, 2), [(4,4), (-8,0)]);
		down_arrow=:((wid - 7, hgt - 3), [(-4,-4), (8,0)]);
		};
DrawArrows wid hgt unable state
	| up && down =  [uup,udown];
	| down =  [uup];
	| up =  [udown];
	=  [];
		where {
		(up,down)=: CanScroll state;
		uup	=: DrawPolygon ((wid - 7, 2), [(4,4), (-8,0)]);
		udown	=: DrawPolygon ((wid - 7, hgt - 3), [(-4,-4), (8,0)]);
		};

DrawItemTitles	:: !Bool !Int !Int !Int !Int !Int !Int !String !Picture -> Picture;
DrawItemTitles able nr base lnht index wid defid state pic
	| nr == 0 || no_more =  pic;
	| defitem && able =  DrawItemTitles able (dec nr) base` lnht index` wid defid state pic1;
	| defitem =  DrawItemTitles able (dec nr) base` lnht index` wid defid state pic2;
	=  DrawItemTitles able (dec nr) base` lnht index` wid defid state pic3;
		where {
		(no_more,index`,item)=: GetItem index state;
		pic1		=: SelectItem wid defy lnht (DrawString item (MovePenTo (3,base) pic));
		pic2		=: UnableSelectItem wid defy lnht (DrawString item (MovePenTo (3,base) pic));
		pic3		=: DrawString item (MovePenTo (3,base) pic);
		base`		=: base + lnht;
		defy		=: base -  base rem lnht ;
		defitem	=: index == defid;
		};

SelectItem	:: !Int !Int !Int !Picture -> Picture;
SelectItem wid y lnht pic
	=  SetPenMode CopyMode (
	      FillRectangle ((0,y),(ItemWid wid, y + lnht)) (
	         SetPenMode HiliteMode pic));

UnableSelectItem	:: !Int !Int !Int !Picture -> Picture;
UnableSelectItem wid y lnht pic
	=  SetPenMode CopyMode (
	      DrawRectangle ((0,y),(ItemWid wid, y + lnht)) (
	         SetPenMode HiliteMode pic));

/*	The ControlFeel. */

ScrollFeel	:: !Int !Int !Int !MouseState !ControlState -> (!ControlState, ![DrawFunction]);
ScrollFeel wid asct lnht (pos,ButtonUp,mod) (StringCS state)
	| action == ScrolledUp || action == ScrolledDown =  (state`,[erase : arrows]);
	=  (state`,[]);
		where {
		state`	=: StringCS (SetAction NoAction state);
		erase		=: EraseRectangle ((inc (ItemWid wid),UpTop),(dec wid,DownBot nrvis lnht));
		arrows	=: DrawArrows wid (inc (nrvis * lnht)) Able state;
		action	=: GetAction state;
		nrvis		=: GetNrVis state;
		};
ScrollFeel wid asct lnht ((x,y),ButtonStillDown,mod) (StringCS state)
	| action == ScrolledDown =  ScrollDown wid asct lnht nrvis y state;
	| action == ScrolledUp =  ScrollUp   wid asct lnht nrvis y state;
	=  (StringCS state`, []);
		where {
		state`	=: SetAction NoAction state;
		nrvis		=: GetNrVis state;
		action	=: GetAction state;
		};
ScrollFeel wid asct lnht ((x,y),buttondown,mod) (StringCS state)
	| InItemList  wid lnht nrvis x y =  SelectNewItem defnr lnht wid (SetAction NoAction state);
	| OnUpArrow   wid x y && down =  (cstat1, [HiliteArrow wid UpTop                : draws1]);
	| OnDownArrow wid lnht nrvis x y && up =  (cstat2, [HiliteArrow wid (DownTop nrvis lnht) : draws2]);
	=  (StringCS (SetAction NoAction state), []);
		where {
		(cstat1,draws1)=: ScrollDown wid asct lnht nrvis y (SetAction ScrolledDown state);
		(cstat2,draws2)=: ScrollUp   wid asct lnht nrvis y (SetAction ScrolledUp state);
		(up,down)=: CanScroll state;
		nrvis		=: GetNrVis state;
		defnr		=: y / lnht;
		};

SelectNewItem	:: !Int !Int !Int !String -> (!ControlState, ![DrawFunction]);
SelectNewItem defnr lnht wid state
	| in_list =  (StringCS state`, draws`);
	=  (StringCS state, []);
		where {
		(in_list,state`,draws)=: SelNewItem defnr 0 lnht first defid wid state;
		draws`=: UnSelOldItem nrvis 0 lnht first defid wid state` draws;
		defid =: GetDefltIndex state;
		first	=: GetFirstIndex state;
		nrvis	=: GetNrVis state;
		};

SelNewItem	:: !Int !Int !Int !Int !Int !Int !String -> (!Bool, !String, ![DrawFunction]);
SelNewItem nr y lnht index defid wid state
	| (found && index == defid) || no_more =  (False, state, []);
	| found =  (True, newst, [SelectItem wid y lnht]);
	=  SelNewItem (dec nr) (y + lnht) lnht index` defid wid state;
		where {
		(no_more,index`,it)=: GetItem index state;
		found=: nr == 0;
		newst=: SetAction Selected (SetDefltIndex index state);
		};

UnSelOldItem	:: !Int !Int !Int !Int !Int !Int !String ![DrawFunction] -> [DrawFunction];
UnSelOldItem nr y lnht index defid wid state draws
	| nr == 0 || no_more =  draws;
	| index == defid =  [SelectItem wid y lnht : draws];
	=  UnSelOldItem (dec nr) (y + lnht) lnht index` defid wid state draws;
		where {
		(no_more,index`,it)=: GetItem index state;
		};

ScrollDown	:: !Int !Int !Int !Int !Int !String -> (!ControlState, ![DrawFunction]);
ScrollDown wid asct lnht nrvis y state
	| y >= UpBot || no_more =  (StringCS state, []);
	| defid == first` =  Wait ticks (StringCS state`, [scroll,move,drawit,select]);
	=  Wait ticks (StringCS state`, [scroll,move,drawit]);
		where {
		(no_more,first`,item)=: GetScrolledDownItem first state;
		state`=: SetFirstIndex first` state;
		first	=: GetFirstIndex state;
		defid	=: GetDefltIndex state;
		scroll=: MoveRectangle ((0,0),(ItemWid wid,lnht *  dec nrvis )) (0,lnht);
		move	=: MovePenTo (3,asct);
		drawit=: DrawString item;
		select=: SelectItem wid 0 lnht;
		ticks =: WaitInterval (UpBot - y);
		};

GetScrolledDownItem	:: !Int !String -> (!Bool, !Int, !String);
GetScrolledDownItem index state
	| index == FirstItemIndex =  (True, index, "");
	=  (False, i, state % (i, index`));
		where {
		i=: FindPreviousItemIndex index` state;
		index`=: index - 2;
		};

ScrollUp	:: !Int !Int !Int !Int !Int !String -> (!ControlState, ![DrawFunction]);
ScrollUp wid asct lnht nrvis y state
	| y <=  DownTop nrvis lnht  || no_more =  (StringCS state, []);
	| defid == lastid =  Wait ticks (StringCS state`, [scroll,move,drawit,select]);
	=  Wait ticks (StringCS state`, [scroll,move,drawit]);
		where {
		(b,first`,it)        =: GetItem first state;
		(no_more,lastid,item)=: GetScrolledUpItem (dec nrvis) first` state;
		state`=: SetFirstIndex first` state;
		first	=: GetFirstIndex state;
		defid	=: GetDefltIndex state;
		scroll=: MoveRectangle ((0,lnht),(ItemWid wid,nrvis * lnht)) (0,0 - lnht);
		move	=: MovePenTo (3,newy + asct);
		drawit=: DrawString item;
		select=: SelectItem wid newy lnht;
		newy	=: lnht *  dec nrvis ;
		ticks =: WaitInterval (y -  DownTop nrvis lnht );
		};

GetScrolledUpItem	:: !Int !Int !String -> (!Bool,!Int,!String);
GetScrolledUpItem nr index state
	| nr == 0 || no_more =  (no_more,index,item);
	=  GetScrolledUpItem (dec nr) index` state;
		where {
		(no_more,index`,item)=: GetItem index state;
		};

CanScroll	:: !String -> (!Bool,!Bool);
CanScroll state =  (not up, not down);
		where {
		(up  ,f2,i2)=: GetScrolledUpItem nrvis first state;
		(down,f1,i1)=: GetScrolledDownItem first state;
		first=: GetFirstIndex state;
		nrvis=: GetNrVis state;
		};

WaitInterval	:: !Int -> Int;
WaitInterval i
	| i <= 0 =  TicksPerSecond / 6;
	=  (TicksPerSecond /  inc (i / 5) ) / 6;

HiliteArrow	:: !Int !Int !Picture -> Picture;
HiliteArrow wid top pic
	=  SetPenMode CopyMode (FillRectangle ((l,top),(r,b)) (SetPenMode XorMode pic));
		where {
		l=: inc (ItemWid wid);
		r=: dec wid;
		b=: top + ArrowHgt;
		};

InItemList	:: !Int !Int !Int !Int !Int -> Bool;
InItemList wid ht nr x y =    x >= 0  &&  x <=  ItemWid wid    &&
	                                ( y >= 0  &&  y <=  nr * ht  );
	
OnUpArrow	:: !Int !Int !Int -> Bool;
OnUpArrow wid x y =    x >  ItemWid wid   &&  x < wid   &&
	                         ( y >= UpTop  &&  y <= UpBot );

OnDownArrow	:: !Int !Int !Int !Int !Int -> Bool;
OnDownArrow wid ht nr x y =    x >  ItemWid wid   &&  x < wid   &&
	                                 ( y >=  DownTop nr ht   &&  y <=  DownBot nr ht  );

/*	The dialog function. */

ScrollDFunc	:: !DialogItemId !(DialogFunction s (IOState s)) !DialogInfo
	            !(DialogState s (IOState s)) -> DialogState s (IOState s);
ScrollDFunc id dfunc dinfo dstate
	|  GetAction state  == Selected =  dfunc dinfo dstate;
	=  dstate;
		where {
		(is_scrlist,state)=: GetScrollState id dinfo;
		};

GetScrollState	:: !DialogItemId !DialogInfo -> (!Bool, !String);
GetScrollState id dialog =  GetScrollStateFromControl (GetControlState id dialog);

GetScrollStateFromControl	:: !ControlState -> (!Bool, !String);
GetScrollStateFromControl (StringCS state) =  (True, state); 
GetScrollStateFromControl cstate =  (False, "");

//
//	The function to change the scrolling list.
//

ChangeScrollingList	:: !DialogItemId !ItemTitle ![ItemTitle]
	                    !(DialogState s (IOState s)) -> DialogState s (IOState s);
ChangeScrollingList id defit items dstate
	| is_scrlist =  ChangeControlState id cstate dstate`;
	=  Error "ChangeScrollingList" "Item is not a ScrollingList" id;
		where {
		cstate				=: StringCS (SetWidth wid state);
		(maxwid,state)		=: InitScrollState font nrvis defit items;
		wid					=: GetWidth oldst;
		(b,font)				=: SelectFont name style size;
		(name,style,size)	=: DefaultFont;
		nrvis					=: GetNrVis oldst;
		(is_scrlist,oldst)=: GetScrollState id dinfo;
		(dinfo,dstate`)   =: DialogStateGetDialogInfo dstate;
		};

//
//	The functions to retrieve the selected item in the scrolling list.
//

GetScrollingListItem	:: !DialogItemId !DialogInfo -> ItemTitle;
GetScrollingListItem id dinfo
	| is_scrlist =  item;
	=  Error "GetScrollingListItem" "Item is not a ScrollingList" id;
		where {
		(b,i,item)			=: GetItem (GetDefltIndex state) state;
		(is_scrlist,state)=: GetScrollState id dinfo;
		};

/*	Access functions on the ControlState */

GetItem	:: !Int !String -> (!Bool, !Int, !String);
GetItem index state
	|  state.[index]  == EndOfList =  (True, index, "");
	=  (False, inc i, state % (index, dec i));
		where {
		i=: NextNlIndex index state;
		};

NextNlIndex	:: !Int !String -> Int;
NextNlIndex i str
	|  str.[i]  == '\n' =  i;
	=  NextNlIndex (inc i) str;

FindPreviousItemIndex	:: !Int !String -> Int;
FindPreviousItemIndex i str
	| i < FirstItemIndex =  FirstItemIndex;
	|  str.[i]  == '\n' =  inc i; 
	=  FindPreviousItemIndex (dec i) str;

GetAction	:: !String -> Char;
GetAction state =  state.[ChangeI];

SetAction	:: !Char !String -> String;
SetAction action state =  state := (ChangeI, action);

GetNrVis	:: !String -> Int;
GetNrVis state =  toInt (state.[NrVisI]);

GetWidth	:: !String -> Int;
GetWidth state =  GetNrFromState WidthI state;

SetWidth	:: !Int !String -> String;
SetWidth wid state =  SetNrInState WidthI wid state;

GetFirstIndex	:: !String -> Int;
GetFirstIndex state =  GetNrFromState FirstI state;

SetFirstIndex	:: !Int !String -> String;
SetFirstIndex first state =  SetNrInState FirstI first state;

GetDefltIndex	:: !String -> Int;
GetDefltIndex state =  GetNrFromState DefltI state;

SetDefltIndex	:: !Int !String -> String;
SetDefltIndex deflt state =  SetNrInState DefltI deflt state;

GetNrFromState	:: !Int !String -> Int;
GetNrFromState index state =   toInt c0  +  256 *  toInt c1  ;
		where {
		c0=: state.[index];
		c1=: state.[inc index];
		};

SetNrInState	:: !Int !Int !String -> String;
SetNrInState index nr state =  (state := (index, c0)) := (inc index, c1);
		where {
		c0=: toChar (nr rem 256);
		c1=: toChar (nr / 256);
		};


/*	General Slider Bar implementation. */

    
::	SliderDirection	= Horizontal | Vertical;
::	SliderMax 			:== Int;
::	SliderPos			:== Int;

     
	SliderW		:== 9;
	SliderH		:== 20;
	SliderM		:== 4;
	FrameTop		:== 8;
	FrameBot		:== 12;
	MinDelta		:== -10;
	MaxDelta		:== 10;

    

//
//	The SliderBar item definition.
//

SliderBar	:: !DialogItemId !ItemPos !SelectState !SliderDirection !SliderPos !SliderMax
	          !(DialogFunction s (IOState s)) -> DialogItem s (IOState s);
SliderBar id pos abty dir=:Horizontal sps smx dfunc
	=  Control id pos ((-1,0),(smax +  inc SliderW ,SliderH)) abty cstate
	           (SliderLook dir) (SliderFeel dir) (SliderDFunc id dfunc);
	   where {
	   cstate=: IntCS ( 1000 * smax  + spos);
	   spos	=: AdjustBetween 0 smax sps;
	   smax	=: AdjustBetween 0 999 smx;
	   };
SliderBar id pos abty dir=:Vertical sps smx dfunc
	=  Control id pos ((0,-1),(SliderH,smax +  inc SliderW )) abty cstate
	           (SliderLook dir) (SliderFeel dir) (SliderDFunc id dfunc);
	   where {
	   cstate=: IntCS ( 1000 * smax  + spos);
	   spos	=: AdjustBetween 0 smax sps;
	   smax	=: AdjustBetween 0 999 smx;
	   };
	
/*	The ControlLook of the slider bar. */

SliderLook	:: !SliderDirection !SelectState !ControlState -> [DrawFunction];
SliderLook dir abty state
	| IsHorizontal dir =  [DrawRectangle ((-1,FrameTop),(smax +  inc SliderW ,FrameBot)) :
	      DrawHorSlider abty spos];
	=  [DrawRectangle ((FrameTop,-1),(FrameBot,smax +  inc SliderW )) :
	      DrawVerSlider abty smax spos];
		where {
		smax=: GetSliderMax state;
		spos=: GetSliderPos state;
		};

DrawHorSlider	:: !SelectState !SliderPos -> [DrawFunction];
DrawHorSlider abty spos
	| not (Enabled abty) =  [erase,draw];
	=  [erase,draw,MovePenTo (linex,3), LinePen (0,SliderH - 7)];
		where {
		erase =: EraseRectangle ((spos,FrameTop),(send,FrameBot));
		draw	=: DrawRoundRectangle (((spos,0),(send,SliderH)),6,6);
		send	=: spos + SliderW;
		linex	=: spos + SliderM;
		};

DrawVerSlider	:: !SelectState !SliderMax !SliderPos -> [DrawFunction];
DrawVerSlider abty smax sps
	| not (Enabled abty) =  [erase,draw];
	=  [erase,draw,MovePenTo (3,liney), LinePen (SliderH - 7,0)];
		where {
		erase =: EraseRectangle ((FrameTop,spos),(FrameBot,send));
		draw	=: DrawRoundRectangle (((0,spos),(SliderH,send)),6,6);
		send	=: spos + SliderW;
		liney	=: spos + SliderM;
		spos	=: smax - sps;
		};

/*	The ControlFeel of the slider bar. */

SliderFeel	:: !SliderDirection !MouseState !ControlState -> (!ControlState, ![DrawFunction]);
SliderFeel dir (pos,ButtonUp,mods) state =  (SetSliderChanged False state, []);
SliderFeel Horizontal ((x,y),buttondown,mods) state
	| mx == spos =  (SetSliderChanged False state, []);
	=  (SetSliderChanged True  state`, MoveHorSlider smax spos spos`);
		where {
		mx		=: AdjustBetween 0 smax (x - SliderM);
		spos	=: GetSliderPos state;
		smax	=: GetSliderMax state;
		state`=: SetSliderPos spos` state;
		spos`	=:  spos +  AdjustBetween MinDelta MaxDelta (mx - spos) ;
		};
SliderFeel Vertical ((x,y),buttondown,mods) state
	| my == spos =  (SetSliderChanged False state, []);
	=  (SetSliderChanged True  state`, MoveVerSlider smax spos spos`);
		where {
		my		=: AdjustBetween 0 smax (y - SliderM);
		spos	=: smax -  GetSliderPos state ;
		smax	=: GetSliderMax state;
		state`=: SetSliderPos (smax - spos`) state;
		spos`	=:  spos +  AdjustBetween MinDelta MaxDelta (my - spos) ;
		};

MoveHorSlider	:: !Int !Int !Int -> [DrawFunction];
MoveHorSlider smax oldx newx
	| newx > oldx =  [move, DrawRectangle ((-1,FrameTop),(inc newx,FrameBot))];
	=  [move, DrawRectangle ((newx +  dec SliderW ,FrameTop),(smax +  inc SliderW ,FrameBot))];
		where {
		move=: MoveRectangleTo ((oldx,0),(oldx + SliderW,SliderH)) (newx,0);
		};

MoveVerSlider	:: !Int !Int !Int -> [DrawFunction];
MoveVerSlider smax oldy newy
	| newy > oldy =  [move, DrawRectangle ((FrameTop,-1),(FrameBot,inc newy))];
	=  [move, DrawRectangle ((FrameTop,newy +  dec SliderW ),(FrameBot,smax +  inc SliderW ))];
		where {
		move=: MoveRectangleTo ((0,oldy),(SliderH,oldy + SliderW)) (0,newy);
		};

/*	The DialogFunction of the slider bar. */

SliderDFunc	:: !DialogItemId !(DialogFunction s (IOState s)) !DialogInfo
	            !(DialogState s (IOState s)) -> DialogState s (IOState s);
SliderDFunc id dfunc dinfo dstate
	| SliderChanged (GetControlState id dinfo) =  dfunc dinfo dstate;
	=  dstate;

GetControlStateFromSlider	:: !ControlState -> (!Bool, !ControlState);
GetControlStateFromSlider cstate=:(IntCS st) =  (True, cstate); 
GetControlStateFromSlider item =  (False, IntCS 0);

//
//	The function to move the slider explicitly
//

ChangeSliderBar	:: !DialogItemId !SliderPos !(DialogState s (IOState s))
                                               -> DialogState s (IOState s);
ChangeSliderBar id sps dstate
	| is_slider =  ChangeControlState id (SetSliderPos spos state) dstate`;
	=  Error "ChangeSliderBar" "Item is not a SliderBar" id;
		where {
		spos					=: AdjustBetween 0 (GetSliderMax state) sps;
		(is_slider,state)	=: GetControlStateFromSlider (GetControlState id dinfo);
		(dinfo,dstate`)   =: DialogStateGetDialogInfo dstate;
		};

//
//	The function to retrieve the position of the slider.
//

GetSliderPosition	:: !DialogItemId !DialogInfo -> SliderPos;
GetSliderPosition id dinfo
	| is_slider =  GetSliderPos state;
	=  Error "GetSliderPosition" "Item is not a SliderBar" id;
		where {
		(is_slider,state)	=: GetControlStateFromSlider (GetControlState id dinfo);
		};

//
//	Access function on the ControlState of the slider bar.
//

SliderChanged	:: !ControlState -> Bool;
SliderChanged (IntCS state) =  state > 1000000;

SetSliderChanged	:: !Bool !ControlState -> ControlState;
SetSliderChanged changed (IntCS state)
	| changed && state < 1000000 =  IntCS (state + 1000000);
	| not changed && state > 1000000 =  IntCS (state - 1000000);
	=  IntCS state;

GetSliderPos	:: !ControlState -> SliderPos;
GetSliderPos (IntCS state) =  state rem 1000;

SetSliderPos	:: !SliderPos !ControlState -> ControlState;
SetSliderPos pos (IntCS state) =  IntCS ( state -  state rem 1000   + pos);

GetSliderMax	:: !ControlState -> SliderMax;
GetSliderMax (IntCS state) =  (state rem 1000000) / 1000;

IsHorizontal	:: !SliderDirection -> Bool;
IsHorizontal Horizontal =  True;
IsHorizontal vertical   =  False;

/* Misc. functions */

Enabled	:: !SelectState -> Bool;
Enabled Able   =  True;
Enabled Unable =  False;

AdjustBetween	:: !Int !Int !Int -> Int;
AdjustBetween min max val | val < min =  min;
	                          | val > max =  max;
	                          =  val;

MeasureToHorPixels	:: !Measure     -> Int;
MeasureToHorPixels (MM    mm)   =  MMToHorPixels mm;
MeasureToHorPixels (Inch  inch) =  InchToHorPixels inch;
MeasureToHorPixels (Pixel p)    =  p;

