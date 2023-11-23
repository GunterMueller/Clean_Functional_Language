definition module windowkeyio


from	iostate import	PSt, IOSt
import	events
import osevent

windowKeyIO :: !OSEvent !(IOSt .l) -> IOSt .l
