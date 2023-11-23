definition module ProcessSerialNumber;

import StdOverloaded;

from ioState import IOState;

:: ProcessSerialNumber;

CreateProcessSerialNumber :: !Int !Int -> !ProcessSerialNumber;

DefaultProcessSerialNumber :: !ProcessSerialNumber;

instance == ProcessSerialNumber;

KillClient2 :: !ProcessSerialNumber !(IOState s) -> !(IOState s);

GetSystemRepresentationOfPSN :: !ProcessSerialNumber -> !(!Int,Int);
