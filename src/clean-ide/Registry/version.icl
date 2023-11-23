implementation module version

import code from library "version_library"

GetFileVersionInfoSize :: !{#Char} !{#Char} !*Int -> (!Int,!*Int)
GetFileVersionInfoSize _ _ _ = code {
	ccall GetFileVersionInfoSizeA@8 "Pss:I:I"
	}

GetFileVersionInfo :: !{#Char} !Int !Int !{#Char} !*Int -> (!Int,!*Int)
GetFileVersionInfo _ _ _ _ _ = code {
	ccall GetFileVersionInfoA@16 "PsIIs:I:I"
	}

VerQueryValue :: !{#Char} !{#Char} !{#Char} !{#Char} !*Int  -> (!Int,!*Int)
VerQueryValue _ _ _ _ _ = code {
	ccall VerQueryValueA@16 "Pssss:I:I"
	}
