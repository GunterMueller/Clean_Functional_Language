definition module mouseevent

import windowhandle, iostate

controlMouseDownIO :: !OSWindowMetrics !OSWindowPtr !Point2 !Int !Int !(WindowStateHandle (PSt .l)) !(WindowHandles (PSt .l)) !(PSt .l)
  -> (!Bool,!Maybe DeviceEvent,!WindowHandles (PSt .l),!WindowStateHandle (PSt .l),!(PSt .l))

changeFocus :: !Bool !(Maybe Int) !(Maybe Int) !OSWindowPtr !OSRect !*(WindowStateHandle .a) !*(PSt .c) -> *(!*(WindowStateHandle .a),!*PSt .c)

