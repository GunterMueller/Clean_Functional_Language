implementation module sliderBar;


/*	General Slider Bar implementation. */


import StdClass; // RWS
import StdInt, StdString, StdChar, StdBool;
import deltaDialog, deltaEventIO, deltaTimer, deltaFont, deltaPicture, deltaSystem;

import commonDef;

::	SliderDirection	=	Horizontal | Vertical;
::	SliderMax 		:==	Int;
::	SliderPos		:==	Int;


SliderW		:==	9;
SliderH		:==	20;
SliderM		:==	4;
FrameTop	:==	8;
FrameBot	:==	12;
MinDelta	:==	-10;
MaxDelta	:==	10;


SliderBarError :: String String Int -> .x;
SliderBarError rule message id
	=	Error rule "sliderBar" (message +++ " (item id = " +++ toString id +++ ")");

//
//	The SliderBar item definition.
//

SliderBar	::	!DialogItemId !ItemPos !SelectState !SliderDirection !SliderPos !SliderMax
				!(DialogFunction s (IOState s))
			->	DialogItem s (IOState s);
SliderBar id pos select dir=:Horizontal sPos sMax dialogF
	=	Control id pos ((-1,0), (sMax` + inc SliderW,SliderH)) select cState
	           (SliderLook dir) (SliderFeel dir) (SliderDFunc id dialogF);
	where {
		cState	= IntCS (1000 * sMax` + sPos`);
		sPos`	= SetBetween sPos 0 sMax`;
		sMax`	= SetBetween sMax 0 999;
	};
SliderBar id pos select dir=:Vertical sPos sMax dialogF
	=	Control id pos ((0,-1),(SliderH,sMax` + inc SliderW)) select cState
	           (SliderLook dir) (SliderFeel dir) (SliderDFunc id dialogF);
	where {
		cState	= IntCS (1000 * sMax` + sPos`);
		sPos`	= SetBetween sPos 0 sMax`;
		sMax`	= SetBetween sMax 0 999;
	};


/*	The ControlLook of the slider bar. */

SliderLook :: !SliderDirection !SelectState !ControlState -> [DrawFunction];
SliderLook dir select cState
|	IsHorizontal dir
	=	[DrawRectangle ((-1,FrameTop),(sMax + inc SliderW,FrameBot)) : DrawHorSlider select sPos];
	=	[DrawRectangle ((FrameTop,-1),(FrameBot,sMax + inc SliderW)) : DrawVerSlider select sMax sPos];
	where {
		sMax = GetSliderMax cState;
		sPos = GetSliderPos cState;
	};

DrawHorSlider :: !SelectState !SliderPos -> [DrawFunction];
DrawHorSlider select sPos
|	not (Enabled select)
	=	[erase, draw];
	=	[erase, draw, MovePenTo (lineX,3), LinePen (0,SliderH - 7)];
	where {
		erase	= EraseRectangle ((sPos, FrameTop), (send, FrameBot));
		draw	= DrawRectangle ((sPos, 0), (send, SliderH));
		send	= sPos + SliderW;
		lineX	= sPos + SliderM;
	};

DrawVerSlider :: !SelectState !SliderMax !SliderPos -> [DrawFunction];
DrawVerSlider select sMax sPos
|	not (Enabled select)
	=	[erase, draw];
	=	[erase, draw, MovePenTo (3,lineY), LinePen (SliderH - 7,0)];
	where {
		erase	= EraseRectangle ((FrameTop, sPos`), (FrameBot, send));
		draw	= DrawRectangle ((0, sPos`), (SliderH, send));
		send	= sPos` + SliderW;
		lineY	= sPos` + SliderM;
		sPos`	= sMax - sPos;
	};


/*	The ControlFeel of the slider bar. */

SliderFeel :: !SliderDirection !MouseState !ControlState -> (!ControlState, ![DrawFunction]);
SliderFeel dir (pos, ButtonUp, mods) cState
	=	(SetSliderChanged False cState, []);
SliderFeel Horizontal ((x,y), buttonDown, mods) cState
|	mX == sPos`	=	(SetSliderChanged False cState, []);
				=	(SetSliderChanged True  cState`, MoveHorSlider sMax sPos` sPos``);
	where {
		mX		= SetBetween (x - SliderM) 0 sMax;
		sPos`	= GetSliderPos cState;
		sMax	= GetSliderMax cState;
		cState`	= SetSliderPos sPos`` cState;
		sPos``	= sPos` + SetBetween (mX - sPos`) MinDelta MaxDelta;
	};
SliderFeel Vertical ((x,y), buttonDown, mods) cState
|	mY == sPos`	=	(SetSliderChanged False cState, []);
				=	(SetSliderChanged True  cState`, MoveVerSlider sMax sPos` sPos``);
	where {
		mY		= SetBetween (y - SliderM) 0 sMax;
		sPos`	= sMax - GetSliderPos cState ;
		sMax	= GetSliderMax cState;
		cState`	= SetSliderPos (sMax - sPos``) cState;
		sPos``	= sPos` + SetBetween (mY - sPos`) MinDelta MaxDelta ;
	};

MoveHorSlider :: !Int !Int !Int -> [DrawFunction];
MoveHorSlider sMax oldX newX
|	newX > oldX	=	[move, DrawRectangle ((-1,FrameTop), (inc newX, FrameBot))];
				=	[move, DrawRectangle ((newX+dec SliderW, FrameTop), (sMax+inc SliderW,FrameBot))];
	where {
		move = MoveRectangle ((oldX,0), (oldX + SliderW,SliderH)) (newX - oldX, 0);
	};

MoveVerSlider :: !Int !Int !Int -> [DrawFunction];
MoveVerSlider sMax oldY newY
|	newY > oldY	=	[move, DrawRectangle ((FrameTop,-1), (FrameBot,inc newY))];
				=	[move, DrawRectangle ((FrameTop,newY+dec SliderW), (FrameBot,sMax+inc SliderW))];
	where {
		move = MoveRectangle ((0, oldY), (SliderH, oldY + SliderW)) (0, newY - oldY);
	};


/*	The DialogFunction of the slider bar. */

SliderDFunc ::	!DialogItemId !(DialogFunction s (IOState s))
				!DialogInfo !(DialogState s (IOState s))
			->	DialogState s (IOState s);
SliderDFunc id dialogF info dState
|	SliderChanged (GetControlState id info)	= dialogF info dState;
											= dState;

GetControlStateFromSlider :: !ControlState -> (!Bool, !ControlState);
GetControlStateFromSlider cState=:(IntCS state)	= (True, cState); 
GetControlStateFromSlider _						= (False, IntCS 0);


//
//	The function to move the slider explicitly.
//

ChangeSliderBar	:: !DialogItemId !SliderPos !(DialogState s (IOState s))
				->	DialogState s (IOState s);
ChangeSliderBar id sPos dState
|	isSlider	= ChangeControlState id (SetSliderPos sPos` cState) dState`;
				= SliderBarError "ChangeSliderBar" "Item is not a SliderBar" id;
	where {
		sPos`				= SetBetween sPos 0 (GetSliderMax cState);
		(isSlider, cState)	= GetControlStateFromSlider (GetControlState id info);
		(info, dState`)		= DialogStateGetDialogInfo dState;
	};


//
//	The function to retrieve the position of the slider.
//

GetSliderPosition :: !DialogItemId !DialogInfo -> SliderPos;
GetSliderPosition id info
|	isSlider	= GetSliderPos cState;
				= SliderBarError "GetSliderPosition" "Item is not a SliderBar" id;
	where {
		(isSlider, cState) = GetControlStateFromSlider (GetControlState id info);
	};


//
//	Access function to the ControlState of the slider bar.
//

SliderChanged :: !ControlState -> Bool;
SliderChanged (IntCS state) = state > 1000000;

SetSliderChanged :: !Bool !ControlState -> ControlState;
SetSliderChanged changed (IntCS state)
|	changed		&& state < 1000000	= IntCS (state+1000000);
|	not changed && state > 1000000	= IntCS (state-1000000);
									= IntCS state;

GetSliderPos :: !ControlState -> SliderPos;
GetSliderPos (IntCS state) = state rem 1000;

SetSliderPos :: !SliderPos !ControlState -> ControlState;
SetSliderPos pos (IntCS state) = IntCS (state-state rem 1000+pos);

GetSliderMax :: !ControlState -> SliderMax;
GetSliderMax (IntCS state) = (state rem 1000000) / 1000;

IsHorizontal :: !SliderDirection -> Bool;
IsHorizontal Horizontal = True;
IsHorizontal vertical   = False;
