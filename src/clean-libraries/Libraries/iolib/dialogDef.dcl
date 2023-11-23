definition module dialogDef;

/* The type definitions for the dialog device.
*/

import commonDef;
from deltaPicture import ::DrawFunction,::Picture;
from xtypes import ::XDialogHandle, ::XDItemHandle, ::Id, ::Widget, ::XHandle;


       
:: DialogInfo;
// :: DialogState * s * io;
:: DialogState * s * io :== DialogHandle s io;
  
/* Type definitions for deltaIOSystem.
*/

:: DialogDef * s * io
   = PropertyDialog DialogId DialogTitle [DialogAttribute] (SetFunction s io)
                     (ResetFunction s io) [DialogItem s io]
   |  CommandDialog  DialogId DialogTitle [DialogAttribute]
                     DialogItemId [DialogItem s io]
   |  AboutDialog    ApplicationName PictureDomain [DrawFunction]
                     (AboutHelpDef s io);

:: ApplicationName :== String;
:: AboutHelpDef * s * io
   = NoHelp
   |  AboutHelp ItemTitle (AboutHelpFunction s io);
:: AboutHelpFunction *s *io :== s -> * ( io -> *(s,io)) ;

:: DialogAttribute
   = DialogPos    Measure Measure
   |  DialogSize   Measure Measure
   |  DialogMargin Measure Measure
   |  ItemSpace    Measure Measure
   |  StandByDialog;

:: DialogId    :== Int;
:: DialogTitle :== String;
:: Measure     = MM Real | Inch Real | Pixel Int;
 
:: DialogItem * s * io
   = DialogButton DialogItemId ItemPos ItemTitle SelectState (ButtonFunction s io)
   |  DialogIconButton DialogItemId ItemPos PictureDomain IconLook
                       SelectState (ButtonFunction s io)
   |  StaticText   DialogItemId ItemPos String
   |  DynamicText  DialogItemId ItemPos TextWidth String
   |  EditText     DialogItemId ItemPos TextWidth NrEditLines String
   |  DialogPopUp  DialogItemId ItemPos SelectState 
                       DialogItemId [RadioItemDef s io]
   |  RadioButtons DialogItemId ItemPos RowsOrColumns DialogItemId
                       [RadioItemDef s io]
   |  CheckBoxes   DialogItemId ItemPos RowsOrColumns [CheckBoxDef s io]
   |  Control      DialogItemId ItemPos PictureDomain SelectState ControlState
                       ControlLook ControlFeel (DialogFunction s io);
 
:: DialogItemId  :== Int;
:: RowsOrColumns = Rows Int | Columns Int;
:: ItemPos       = Left | Center | Right        |
                    RightTo DialogItemId         |
                    Below DialogItemId           |
                    XOffset DialogItemId Measure |
                    YOffset DialogItemId Measure |
                    XY Measure Measure           |
                    ItemBox Int Int Int Int;
:: IconLook      :== SelectState -> [DrawFunction];
:: TextWidth     :== Measure;
:: NrEditLines   :== Int;
:: RadioItemDef * s * io
   = RadioItem DialogItemId ItemTitle SelectState (DialogFunction s io);
:: CheckBoxDef * s * io
   = CheckBox DialogItemId ItemTitle SelectState MarkState (DialogFunction s io);
 
:: ControlState = IntCS    Int                       |
                   BoolCS   Bool                      |
                   RealCS   Real                      | 
                   StringCS String                    |
                   PairCS   ControlState ControlState |
                   ListCS   [ControlState];
:: ControlLook :== SelectState ->  ControlState -> [DrawFunction] ;
:: ControlFeel :== MouseState ->   ControlState -> (ControlState,[DrawFunction]) ;
 
:: SetFunction    * s * io :== ButtonFunction s io;
:: ResetFunction  * s * io :== ButtonFunction s io;
:: DialogFunction * s * io
   :== DialogInfo ->  (DialogState s io) ->  DialogState s io  ;
:: ButtonFunction * s * io
   :== DialogInfo ->  s ->   * (io -> *(s, io))  ;

:: NoticeDef       = Notice [String] NoticeButtonDef [NoticeButtonDef];
:: NoticeButtonDef = NoticeButton NoticeButtonId ItemTitle;
:: NoticeButtonId  :== Int;


/* Type definitions for ioState.
*/

:: DialogHandle * s * io
   = DialHandle DialogMode XDialogHandle [XDItemHandle] (DialogDef s io);
:: DialogMode = Modal | Modeless;
::	ItemInfo   :== ([(DialogItemId,String)],
                  [(DialogItemId,DialogItemId)],
                  [(DialogItemId,[(DialogItemId,Bool)])],
                  [(DialogItemId,ControlState)]);

/* Rules for internal access on the DialogState 
*/

    
DState2DHandle :: !(DialogState  s io) -> DialogHandle s io;
DHandle2DState :: !(DialogHandle s io) -> DialogState  s io;
DialogInfo2ItemInfo :: !DialogInfo -> ItemInfo;
DDef2DInfo :: !(DialogDef s io) -> DialogInfo;

