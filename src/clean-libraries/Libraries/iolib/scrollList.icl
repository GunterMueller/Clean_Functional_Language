implementation module scrollList;


/* General Scrolling List implementation. */


import StdClass, StdMisc; // RWS
import StdInt, StdString, StdChar, StdBool, StdArray;
import deltaDialog, deltaEventIO, deltaTimer, deltaFont, deltaPicture, deltaSystem;
import commonDef;

 
::	NrVisible  		:== Int;


ChangeI				:== 0;
NrVisI				:== 1;
WidthI				:== 2;
FirstI				:== 4;
DefltI				:== 6; 
FirstItemIndex		:== 8;
ItemWid width		:== width - 13;
DownTop nr ht		:== DownBot nr ht - ArrowHgt;
DownBot nr ht		:== nr * ht;
UpTop				:== 0;
UpBot				:== ArrowHgt;
ArrowHgt			:== 17;
NoAction			:== '0';
Selected			:== '1';
ScrolledUp			:== '2';
ScrolledDown		:== '3';
EndOfList			:== '\\';		// there is no test on the value of EndOfList


ScrollListError :: String String Int -> .x;
ScrollListError rule message id
	=	Error rule "scrollList" (message +++ " (item id = " +++ toString id +++ ")");


//
//	The ScrollingList item definition.
//

ScrollingList	::	!DialogItemId !ItemPos !Measure !SelectState !NrVisible !ItemTitle ![ItemTitle]
					!(DialogFunction s (IOState s))
				->	DialogItem s (IOState s);
ScrollingList id pos minWidth select nrVisible defaultItem items dialogF
	=	Control id pos ((-1,-1),(width,height)) select cState (ScrollLook font width at_new lineH)
			(ScrollFeel width at_new lineH) (ScrollDFunc id dialogF);
	where {
		cState				= StringCS (SetWidth width sState);
		(maxWidth, sState)	= InitScrollState font nrVisible defaultItem items;
		width				= max (MeasureToHorPixels minWidth) maxWidth + 20;
		height				= inc (nrVisible * lineH);
		lineH				= at_new + dt + ld;
		(at_new, dt, _, ld) = FontMetrics font;
		(_, font)			= SelectFont name style size;
		(name, style, size)	= DefaultFont;
	};


/*	The initial ControlState. */

InitScrollState :: !Font !Int !ItemTitle ![ItemTitle] -> (!Int, !String);
InitScrollState font nrVisible defaultItem items
	=	(maxWidth, SetNewFirst (nrVisible - realNrVisible) first state);
	where {
		(maxWidth,state)= CreateScrollState font nrVisible "" 0 False FirstItemIndex defaultItem items;
		realNrVisible	= NrItemsVisible nrVisible 0 first state;
		first			= GetFirstIndex state;
	};

CreateScrollState :: !Font !Int !String !Int !Bool !Int !ItemTitle ![ItemTitle]
	-> (!Int, !String);
CreateScrollState font nrVisible state maxWidth found index defaultItem [item : items]
|	found || defaultItem == item
	= CreateScrollState font nrVisible state` maxWidth` True index defaultItem items;
	= CreateScrollState font nrVisible state` maxWidth` found (index + len) defaultItem items;
	where {
		state`		= state +++ item +++ "\n";
		maxWidth`	= max maxWidth (FontStringWidth item font);
		len		= inc (size item);
	};
CreateScrollState font nrVisible state maxWidth found index defaultItem items
|	found
	= (maxWidth, SetFirstIndex index (SetDefltIndex index state`));
	= (maxWidth, SetFirstIndex FirstItemIndex (SetDefltIndex FirstItemIndex state`));
	where {
		state` = ((toString Selected +++ toString (toChar nrVisible)) +++ "      ") +++ state +++ toString EndOfList;
	};

NrItemsVisible :: !Int !Int !Int !String -> Int;
NrItemsVisible nrVisible itemNr index state
|	nrVisible == 0 || noMore	= itemNr;
								= NrItemsVisible (dec nrVisible) (inc itemNr) index` state;
	where {
		(noMore, index`, _)	= GetItem index state;
	};

SetNewFirst	:: !Int !Int !String -> String;
SetNewFirst itemNr index state
|	itemNr <= 0 || noMore		= SetFirstIndex index state;
								= SetNewFirst (dec itemNr) index` state;
	where {
		(noMore, index`, _)	= GetScrolledDownItem index state;
	};


/*	The ControlLook. */

ScrollLook :: !Font !Int !Int !Int !SelectState !ControlState -> [DrawFunction];
ScrollLook font width ascent lineH select (StringCS state)
	=	[background, erase, frame,move,line,items : arrows];
	where {
		items		= DrawItemTitles able nrVisible ascent lineH first width defId state;
		able		= Enabled select;
		arrows		= DrawArrows width height select state;
		background  = SetBackColour WhiteColour;
		erase       = EraseRectangle framerect;
		frame		= DrawRectangle framerect;
		move		= MovePenTo (ItemWid width,-1);
		line		= LinePen (0, height);
		framerect   = ((-1,-1), (width,height));
		height		= inc (nrVisible * lineH);
		nrVisible	= GetNrVis state;
		first		= GetFirstIndex state;
		defId		= GetDefltIndex state;
	};

DrawArrows :: !Int !Int !SelectState !String -> [DrawFunction];
DrawArrows width height Able state
|	up && down		= [up1,up2,up3,down1,down2,down3];
|	down			= [up1,up2,up3];
|	up				= [down1,down2,down3];
					= [];
	where {
		(up, down)	= CanScroll state;
		up1			= FillPolygon upArrow;
		up2			= FillPolygon (MovePolygon (0,3) upArrow);
		up3			= FillPolygon (MovePolygon (0,9) upArrow);
		down1		= FillPolygon downArrow;
		down2		= FillPolygon (MovePolygon (0,-3) downArrow);
		down3		= FillPolygon (MovePolygon (0,-9) downArrow);
		upArrow		= ((width - 7, 2), [(4,4), (-8,0)]);
		downArrow	= ((width - 7, height - 3), [(-4,-4), (8,0)]);
	};
DrawArrows width height unable state
|	up && down		= [up1,down1];
|	down			= [up1];
|	up				= [down1];
					= [];
	where {
		(up, down)	= CanScroll state;
		up1			= DrawPolygon ((width - 7, 2), [(4,4), (-8,0)]);
		down1		= DrawPolygon ((width - 7, height - 3), [(-4,-4), (8,0)]);
	};

DrawItemTitles	:: !Bool !Int !Int !Int !Int !Int !Int !String !Picture -> Picture;
DrawItemTitles able nr base lineH index width defId state pic
|	nr == 0 || noMore		= pic;
|	defItem && able			= DrawItemTitles able (dec nr) base` lineH index` width defId state pic1;
|	defItem					= DrawItemTitles able (dec nr) base` lineH index` width defId state pic2;
							= DrawItemTitles able (dec nr) base` lineH index` width defId state pic3;
	where {
		(noMore,index`,item)= GetItem index state;
		pic1				= SelectItem		width defY lineH pic3; 
		pic2				= UnableSelectItem	width defY lineH pic3;
		pic3				= DrawString item (MovePenTo (3,base) pic);
		base`				= base + lineH;
		defY				= base - base rem lineH;
		defItem				= index == defId;
	};
 
SelectItem :: !Int !Int !Int !Picture -> Picture;
SelectItem width y lineH pic
	=  SetPenMode CopyMode (
			FillRectangle ((0,y),(ItemWid width, y + lineH)) (
			SetPenMode HiliteMode pic));

UnableSelectItem :: !Int !Int !Int !Picture -> Picture;
UnableSelectItem width y lineH pic
	=  SetPenMode CopyMode (
			DrawRectangle ((0,y),(ItemWid width, y + lineH)) (
			SetPenMode HiliteMode pic));


/*	The ControlFeel. */

ScrollFeel :: !Int !Int !Int !MouseState !ControlState -> (!ControlState, ![DrawFunction]);
ScrollFeel width ascent lineH (pos, ButtonUp, mods) (StringCS state)
|	action == ScrolledUp
||	action == ScrolledDown		= (state`, [erase : arrows]);
								= (state`, []);
	where {
		state`	= StringCS (SetAction NoAction state);
		erase	= EraseRectangle ((inc (ItemWid width), UpTop), (dec width, DownBot nrVis lineH));
		arrows	= DrawArrows width (inc (nrVis * lineH)) Able state;
		action	= GetAction state;
		nrVis	= GetNrVis  state;
	};
ScrollFeel width ascent lineH ((x,y), ButtonStillDown, mods) (StringCS state)
| action == ScrolledDown		= ScrollDown width ascent lineH nrVis y state;
| action == ScrolledUp			= ScrollUp   width ascent lineH nrVis y state;
								= (StringCS state`, []);
	where {
		state`	= SetAction NoAction state;
		nrVis	= GetNrVis  state;
		action	= GetAction state;
	};
ScrollFeel width ascent lineH ((x,y), buttonDown, mods) (StringCS state)
|	InItemList  width lineH nrVis x y			= SelectNewItem defNr lineH width
													(SetAction NoAction state);
|	OnUpArrow   width x y			  && down	= (state1, [HiliteArrow width UpTop		: draws1]);
|	OnDownArrow width lineH nrVis x y && up		= (state2, [HiliteArrow width downTop	: draws2]);
												= (StringCS (SetAction NoAction state), []);
	where {
		(state1, draws1)	= ScrollDown width ascent lineH nrVis y (SetAction ScrolledDown state);
		(state2, draws2)	= ScrollUp   width ascent lineH nrVis y (SetAction ScrolledUp	state);
		(up, down)			= CanScroll state;
		downTop				= DownTop nrVis lineH;
		nrVis				= GetNrVis state;
		defNr				= y / lineH;
	};

SelectNewItem :: !Int !Int !Int !String -> (!ControlState, ![DrawFunction]);
SelectNewItem defNr lineH width state
|	inList	= (StringCS state`, draws`);
			= (StringCS state,  []);
	where {
		(inList,state`,draws)	= SelNewItem defNr 0 lineH first defId width state;
		draws`					= UnSelOldItem nrVis 0 lineH first defId width state` draws;
		defId					= GetDefltIndex state;
		first					= GetFirstIndex state;
		nrVis					= GetNrVis		state;
	};

SelNewItem :: !Int !Int !Int !Int !Int !Int !String -> (!Bool, !String, ![DrawFunction]);
SelNewItem nr y lineH index defId width state
|	(found && index == defId) || noMore	= (False, state, []);
|	found								= (True, state`, [SelectItem width y lineH]);
										= SelNewItem (dec nr) (y+lineH) lineH index` defId width state;
	where {
		(noMore, index`, _)	= GetItem index state;
		found					= nr == 0;
		state`					= SetAction Selected (SetDefltIndex index state);
	};

UnSelOldItem :: !Int !Int !Int !Int !Int !Int !String ![DrawFunction] -> [DrawFunction];
UnSelOldItem nr y lineH index defId width state draws
|	nr == 0 || noMore	= draws;
|	index == defId		= [SelectItem width y lineH : draws];
						= UnSelOldItem (dec nr) (y + lineH) lineH index` defId width state draws;
	where {
		(noMore, index`, _) = GetItem index state;
	};

ScrollDown :: !Int !Int !Int !Int !Int !String -> (!ControlState, ![DrawFunction]);
ScrollDown width ascent lineH nrVis y state
|	y >= UpBot || noMore	= (StringCS state, []);
|	defId == first`			#!
                                 ticks=ticks; 
							  = Wait ticks (StringCS state`, [scroll,erase,move,drawit,select]);
							#! 
                                 ticks=ticks; 
							  = Wait ticks (StringCS state`, [scroll,erase,move,drawit]);
	where {
		(noMore,first`,item)= GetScrolledDownItem first state;
		state`				= SetFirstIndex first` state;
		first				= GetFirstIndex state;
		defId				= GetDefltIndex state;
		scroll				= CopyRectangle ((0,0),(right,bottom)) (0,lineH);
		right				= ItemWid width;
		bottom				= lineH * dec nrVis;
		erase				= EraseRectangle ((0,top`),(right,bottom`));
		(top`, bottom`)		= if (lineH < 0) (bottom + lineH, bottom) (0, lineH);
		move				= MovePenTo (3,ascent);
		drawit				= DrawString item;
		select				= SelectItem width 0 lineH;
		ticks 				= WaitInterval (UpBot - y);
	};

GetScrolledDownItem	:: !Int !String -> (!Bool, !Int, !String);
GetScrolledDownItem index state
|	index == FirstItemIndex	= (True, index, "");
							= (False, i, state % (i, index`));
	where {
		i		= FindPreviousItemIndex index` state;
		index`	= index-2;
	};

ScrollUp :: !Int !Int !Int !Int !Int !String -> (!ControlState, ![DrawFunction]);
ScrollUp width ascent lineH nrVis y state
|	y <= DownTop nrVis lineH ||	noMore	= (StringCS state, []);
|	defId == lastid						= Wait ticks (StringCS state`,[scroll,erase,move,drawit,select]);
										= Wait ticks (StringCS state`,[scroll,erase,move,drawit]);
	where {
		(_, first`, _)		= GetItem first state;
		(noMore,lastid,item)= GetScrolledUpItem (dec nrVis) first` state;
		state`				= SetFirstIndex first` state;
		first				= GetFirstIndex state;
		defId				= GetDefltIndex state;
		scroll				= CopyRectangle ((0,lineH),(right,bottom)) (0,0 - lineH);
		right				= ItemWid width;
		bottom				= nrVis * lineH;
		erase				= EraseRectangle ((0,top`),(right,bottom`));
		(top`, bottom`)		= if (lineH < 0) (lineH, 0) (bottom - lineH, bottom);
		move				= MovePenTo (3,newy + ascent);
		drawit				= DrawString item;
		select				= SelectItem width newy lineH;
		newy				= lineH *  dec nrVis;
		ticks 				= WaitInterval (y - DownTop nrVis lineH );
	};

GetScrolledUpItem :: !Int !Int !String -> (!Bool, !Int, !String);
GetScrolledUpItem nr index state
|	nr == 0 || noMore	= (noMore, index, item);
						= GetScrolledUpItem (dec nr) index` state;
	where {
		(noMore, index`, item) = GetItem index state;
	};

CanScroll :: !String -> (!Bool, !Bool);
CanScroll state
	=	(not up, not down);
	where {
		(up,   _, _)	= GetScrolledUpItem nrVis first state;
		(down, _, _)	= GetScrolledDownItem first state;
		first			= GetFirstIndex state;
		nrVis			= GetNrVis state;
	};

WaitInterval :: !Int -> Int;
WaitInterval i
|	i <= 0	= TicksPerSecond / 6;
			= (TicksPerSecond / inc (i / 5) ) / 6;

HiliteArrow :: !Int !Int !Picture -> Picture;
HiliteArrow width top pic
	=	SetPenMode CopyMode (
			FillRectangle ((l,top),(r,b)) (
			SetPenMode XorMode pic));
	where {
		l = inc (ItemWid width);
		r = dec width;
		b = top + ArrowHgt;
	};

InItemList :: !Int !Int !Int !Int !Int -> Bool;
InItemList width ht nr x y
	=	x >= 0 && x <= ItemWid width && (y >= 0 && y <= nr * ht);
	
OnUpArrow :: !Int !Int !Int -> Bool;
OnUpArrow width x y
	=	x > ItemWid width && x < width && (y >= UpTop && y <= UpBot);

OnDownArrow :: !Int !Int !Int !Int !Int -> Bool;
OnDownArrow width ht nr x y
	=	x > ItemWid width && x < width && (y >= DownTop nr ht && y <= DownBot nr ht);


/*	The dialog function. */

ScrollDFunc	::	!DialogItemId !(DialogFunction s (IOState s)) !DialogInfo
				!(DialogState s (IOState s))
			->	  DialogState s (IOState s);
ScrollDFunc id dialogF info dState
|	GetAction cState == Selected	= dialogF info dState;
									= dState;
	where {
		(_, cState)		= GetScrollState id info;
	};

GetScrollState :: !DialogItemId !DialogInfo -> (!Bool, !String);
GetScrollState id info = GetScrollStateFromControl (GetControlState id info);

GetScrollStateFromControl :: !ControlState -> (!Bool, !String);
GetScrollStateFromControl (StringCS state)	= (True, state); 
GetScrollStateFromControl _					= (False, "");


//
//	The function to change the scrolling list.
//

ChangeScrollingList	::	!DialogItemId !ItemTitle ![ItemTitle]
						!(DialogState s (IOState s))
					->	  DialogState s (IOState s);
ChangeScrollingList id defItem items dState
|	isScrollList	= ChangeControlState id cState dState`;
					= ScrollListError "ChangeScrollingList" "Item is not a ScrollingList" id;
	where {
		cState					= StringCS (SetWidth width state);
		(_, state)		        = InitScrollState font nrVis defItem items;
		width					= GetWidth oldState;
		(_, font)				= SelectFont name style size;
		(name, style, size)		= DefaultFont;
		nrVis					= GetNrVis oldState;
		(isScrollList, oldState)= GetScrollState id info;
		(info, dState`)			= DialogStateGetDialogInfo dState;
	};


//
//	The functions to retrieve the selected item in the scrolling list.
//

GetScrollingListItem :: !DialogItemId !DialogInfo -> ItemTitle;
GetScrollingListItem id info
|	isScrollList	= item;
					= ScrollListError "GetScrollingListItem" "Item is not a ScrollingList" id;
	where {
		(_, _, item)			= GetItem (GetDefltIndex state) state;
		(isScrollList, state)	= GetScrollState id info;
	};


/*	Access functions to the ControlState. */

GetItem	:: !Int !String -> (!Bool, !Int, !String);
GetItem index state
//	-> (TRUE, index, ""),	IF =C (INDEX state index) EndOfList		== alternative changed
|	dec (size state)  == index	= (True, index, "");			// into this one
									= (False, inc i, state % (index, dec i));
	where {
		i = NextNlIndex index state;
	};

NextNlIndex	:: !Int !String -> Int;
NextNlIndex i str
|	str.[i] == '\n'	= i;
							= NextNlIndex (inc i) str;

FindPreviousItemIndex :: !Int !String -> Int;
FindPreviousItemIndex i str
|	i < FirstItemIndex		= FirstItemIndex;
|	str.[i] == '\n'	= inc i; 
							= FindPreviousItemIndex (dec i) str;

GetAction :: !String -> Char;
GetAction state = state.[ChangeI];

SetAction :: !Char !String -> String;
SetAction action state = state := (ChangeI, action);

GetNrVis :: !String -> Int;
GetNrVis state = toInt (state.[NrVisI]);

GetWidth :: !String -> Int;
GetWidth state = GetNrFromState WidthI state;

SetWidth :: !Int !String -> String;
SetWidth width state = SetNrInState WidthI width state;

GetFirstIndex :: !String -> Int;
GetFirstIndex state = GetNrFromState FirstI state;

SetFirstIndex :: !Int !String -> String;
SetFirstIndex first state = SetNrInState FirstI first state;

GetDefltIndex :: !String -> Int;
GetDefltIndex state = GetNrFromState DefltI state;

SetDefltIndex :: !Int !String -> String;
SetDefltIndex deflt state = SetNrInState DefltI deflt state;

GetNrFromState :: !Int !String -> Int;
GetNrFromState index state
	=	toInt c0 + 256 * toInt c1;
	where {
		c0 = state.[index];
		c1 = state.[inc index];
	};

SetNrInState :: !Int !Int !String -> String;
SetNrInState index nr state
	=	(state := (index, c0)) := (inc index, c1);
	where {
		c0 = toChar (nr rem 256);
		c1 = toChar (nr / 256);
	};


/* Misc. functions */

MeasureToHorPixels :: !Measure		-> Int;
MeasureToHorPixels (MM		mm)		= MMToHorPixels		mm;
MeasureToHorPixels (Inch	inch)	= InchToHorPixels	inch;
MeasureToHorPixels (Pixel	p)		= p;
