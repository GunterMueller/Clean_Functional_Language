definition module Version;

from StdInt import bitand;

:: Version = {
		major	:: !Int
	,	minor	:: !Int
	};
	
DefaultVersion :: !Version;
	
toVersion :: !Int -> !Version;

fromVersion :: !Version -> !Int;

getVersionNumber version :== version bitand 0x00ffffff;