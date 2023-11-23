module StoreDynamicExample

import SendDynamic

import code from library "StaticClientChannel_library"

// copies only the dynamic and its dependencies to a user specified folder
Start world
	= StoreDynamic "cbe4254fe64c315412e4747490a33ba8.sysdyn" [] "C:\\Storage\\" world 
	