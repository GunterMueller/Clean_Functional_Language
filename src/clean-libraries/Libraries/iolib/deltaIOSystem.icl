implementation module deltaIOSystem;

//
//	DeviceDefinitions:
//

import timerDef, menuDef, windowDef, dialogDef;

::	IOSystem		 * s * io :== [DeviceSystem s io];
::	DeviceSystem * s * io = TimerSystem	[TimerDef	s io]
									  |  MenuSystem	[MenuDef 	s io]
									  |  WindowSystem	[WindowDef	s io]
									  |  DialogSystem	[DialogDef	s io];
