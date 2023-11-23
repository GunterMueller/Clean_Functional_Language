definition module mac_types;

::	Ptr :== Int;
::	Handle :== Int;
::	Rect :== (!Int,!Int,!Int,!Int);
::	RgnHandle :== Int;
::	WindowPtr :== Int;
::	Event :== (!Bool,!Int,!Int,!Int,!Int,!Int,!Int);
::	DialogPtr :== Int;
::	MacMenuHandle :== Int;

::	Toolbox :== Int;

NewToolbox :: *Toolbox;
