definition module ProcessSerialNumber;

// winos
from StdOverloaded import class toString, class ==;

:: ProcessSerialNumber;

CreateProcessSerialNumber :: !Int -> ProcessSerialNumber;

DefaultProcessSerialNumber :: ProcessSerialNumber;

GetOSProcessSerialNumber :: !ProcessSerialNumber -> Int;

instance == ProcessSerialNumber;

KillClient2 :: !ProcessSerialNumber !*f ->  *f;

instance toString ProcessSerialNumber;