module CollectorExample

import Collector

dynamicname = "C:\\WINDOWS\\DESKTOP\\distribution\\Examples\\Dynamic 0.0\\WriteDynamic\\test"
			    
Start world 
	#( trees, list, world ) = listBuilder [dynamicname] [] world
	= collectReferenced trees

