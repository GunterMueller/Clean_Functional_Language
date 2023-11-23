implementation module FamkeKernel

import StdDynamic
import FamkeTcpIp
import StdFile
import StdBool, StdMisc, StdString, StdList, StdArray, DynID
from DynamicGraphConversion import string_to_dynamic, class EncodedDynamic (dynamic_to_string), instance EncodedDynamic String
from DynamicLinkerInterface import GetDynamicLinkerPath
from StdDynamicLowLevelInterface import
	class BinaryDynamicIO,
	:: DynamicHeader, :: BinaryDynamicIO_String, :: DynamicInfo{di_lazy_dynamics_a, di_library_index_to_library_name},
	instance BinaryDynamicIO BinaryDynamicIO_String,
	open_binary_dynamic_io_string, read_dynamic_header, read_rts_info_from_dynamic, close_binary_dynamic_io_string

TRACE msg x :== x//trace_n msg x; import StdDebug

:: FamkeServer a b 
	:== TcpIp .(FamkeChannel b a)

:: FamkeChannel a b 
	:== TcpIp String

famkeOpen :: !(FamkePort .a .b) !*World -> (!Bool, FamkePort .a .b, *FamkeServer .a .b, !*World)
famkeOpen comport famke
	# (ip, port, famke) = toTcpIpPort comport famke
	  (ok, port, tcpip, famke) = listenTcpIp port famke
	| not ok = (False, abort "famkeOpen failed", abort "famkeOpen failed", famke)
	= (True, FamkeServer ip port, tcpip, famke)

famkeAccept :: !Bool !*(FamkeServer .a .b) !*World -> (!Bool, !*FamkeChannel .b .a, !*FamkeServer .a .b, !*World)
famkeAccept blocking tcpip famke
	# (ok, comm, tcpip) = receiveTcpIp blocking tcpip
	= (ok, comm, tcpip, famke)

famkeClose :: !*(FamkeServer .a .b) !*World -> *World
famkeClose tcpip famke
	# (ok, famke) = closeTcpIp tcpip famke
	| not ok = abort "famkeClose failed"
	= famke

famkeConnect :: !Bool !(FamkePort .a .b) !*World -> (!Bool, !*FamkeChannel .a .b, !*World)
famkeConnect blocking comport famke
	# (ip, FixedPort port, famke) = toTcpIpPort comport famke
	  (ok, comm, famke) = connectTcpIp blocking ip port famke
	| not ok && blocking = famkeConnect blocking comport famke
	= (ok, comm, famke)

famkeDisconnect :: !*(FamkeChannel .a .b) !*World -> *World
famkeDisconnect comm famke
	# (ok, famke) = closeTcpIp comm famke
	| not ok = abort "famkeDisconnect failed"
	= famke

famkeSend :: a !*(FamkeChannel a .b) !*World -> (!Bool, !*FamkeChannel a .b, !*World) | TC a
famkeSend x comm famke
	# d = dynamic x :: a^
	  famke = TRACE (case d of
		(s :: String) -> "famkeSendDynamic: " +++ s +++ " :: String.\n"
		d -> "famkeSendDynamic: ? :: " +++ toString (typeCodeOfDynamic d) +++ ".\n") famke
	  (s, famke) = dynamicToString d famke
	  (ok, comm) = sendTcpIp s comm
	| not ok = (False, comm, famke)
	# (comm, famke) = handleRequestsForFiles comm famke//{famke & world = world}
	= (True, comm, famke)
where
	handleRequestsForFiles comm famke//=:{world}
		# (_, f, comm) = receiveTcpIp True comm
		| f == "" = (comm, famke)
		# (data, famke) = readFileInDynamicPath f famke
		  (ok, comm) = sendTcpIp data comm
		= handleRequestsForFiles comm famke//{famke & world = world}

famkeReceive :: !Bool !*(FamkeChannel .a b) !*World -> (!Bool, b, !*FamkeChannel .a b, !*World) | TC b
famkeReceive blocking comm famke
	# (ok, s, comm) = receiveTcpIp blocking comm
	| not ok = (False, abort "famkeReceiveDynamic: nothing received", comm, famke)
	# (s, sysdyns, libtyps) = fileReferencesInDynamicAsString ("" +++. s)
      (comm, famke/*=:{world}*/) = doRequestsForFiles (sysdyns ++ libtyps) comm famke
	  (d, famke) = stringToDynamic s famke
	# famke = TRACE (case d of
		(s :: String) -> "famkeReceiveDynamic: " +++ s +++ " :: String.\n"
		d -> "famkeReceiveDynamic: ? :: " +++ toString (typeCodeOfDynamic d) +++ ".\n") famke
	= case d of
		(x :: b^) -> (True, x, comm, famke)
		_ -> abort "famkeReceive: Type pattern match failed"
where
	doRequestsForFiles [] comm famke 
		# (ok, comm) = sendTcpIp "" comm
		= (comm, famke)
	doRequestsForFiles [f:fs] comm famke//=:{world}
		# (exists, famke) = fileExistsInDynamicPath f famke
		| exists = doRequestsForFiles fs comm famke//{famke & world = world}
		# (ok, comm) = sendTcpIp f comm
		  (_, data, comm) = receiveTcpIp True comm
		  famke = writeFileInDynamicPath f data famke
		= doRequestsForFiles fs comm famke//{famke & world = world}

StartKernel :: !Int !.(*World -> *World) !*World -> *World
StartKernel id f world
//	# {world} = f {processId = id, world = world}
	# world = f (cast id)
	= world
where
	cast :: !.a -> .b
	cast _ = code inline {
			pop_a	0
		}
/*
instance TcpIp World
where
	listenTcpIp port famke=:{world}
		# (ok, port, tcpip, world) = listenTcpIp port world
		= (ok, port, tcpip, {famke & world = world})

	connectTcpIp blocking ip port famke=:{world}
		# (ok, tcpip, world) = connectTcpIp blocking ip port world
		= (ok, tcpip, famke & world = world})

	resolveTcpIp hostname famke=:{world}
		# (ok, ip, world) = resolveTcpIp hostname world
		= (ok, ip, {famke & world = world})

instance FileSystem World
where
	fopen name mode famke=:{world}
		# (ok, file, world) = fopen name mode world
		= (ok, file, {famke & world = world})

	fclose file famke=:{world}
		# (ok, world) = fclose file world
		= (ok, {famke & world = world})

	stdio famke=:{world}
		# (file, world) = stdio world
		= (file, {famke & world = world})

	sfopen name mode famke=:{world}
		# (ok, file, world) = sfopen name mode world
		= (ok, file, {famke & world = world})
*/
toTcpIpPort :: !(FamkePort .a .b) !*World -> (!Int, !TcpIpPort, !*World)
toTcpIpPort (FamkeProcessServer ip) famke
//	# (_, ip, famke) = localhostIp famke
	= (ip, FixedPort 0xFA00, famke)
toTcpIpPort FamkeNameServer famke
	# (_, ip, famke) = localhostIp famke
	= (ip, FixedPort 0xFA01, famke)
toTcpIpPort (FamkeServer famkeIp famkePort) famke = (famkeIp, FixedPort famkePort, famke)
toTcpIpPort FamkeAnyServer famke 
	# (_, ip, famke) = localhostIp famke
	= (ip, AnyPort, famke)

dynamicToString :: !Dynamic !*World -> (!*String, !*World)
dynamicToString d world 
	# (ok, s) = dynamic_to_string d
	| not ok = abort "dynamic_to_string failed"
	= (s, world)

stringToDynamic :: !String !*World -> (!Dynamic, !*World)
stringToDynamic s world 
	# (ok, d) = string_to_dynamic s
	| not ok = abort "string_to_dynamic failed"
	= (d, world)

fileReferencesInDynamicAsString :: !*String -> (!*String, ![String], ![String])
fileReferencesInDynamicAsString s
		# f = open_binary_dynamic_io_string s
		  (ok, header, f) = read_dynamic_header f
		| not ok = abort "fileReferencesInDynamicAsString: read_dynamic_header failed"
		# (ok, info, f) = read_rts_info_from_dynamic header f
		| not ok = abort "fileReferencesInDynamicAsString: read_rts_info_from_dynamic failed"
		# sysdyns = map toSysDyn [name \\ name <-: info.di_lazy_dynamics_a]
		  (libs, typs) = unzip (map toLibTyp [name \\ name <-: info.di_library_index_to_library_name])
		= (close_binary_dynamic_io_string f, sysdyns, typs ++ libs)
	where 
		toSysDyn name = "\\" +++ DS_SYSTEM_DYNAMICS_DIR +++ "\\" +++ name +++ "." +++ EXTENSION_SYSTEM_DYNAMIC
		toLibTyp name = (ADD_CODE_LIBRARY_EXTENSION lib_typ, ADD_TYPE_LIBRARY_EXTENSION lib_typ)
		where
			lib_typ = CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION "" name
	
readFileInDynamicPath :: !String !*World -> (!String, !*World)
readFileInDynamicPath name world
	# (ok, file, world) = fopen (GetDynamicLinkerPath +++ name) FReadData world
	| not ok = abort "fopen failed"
	# (ok, file) = fseek file 0 FSeekEnd
	| not ok = abort "fseek failed"
	# (filesize, file) = fposition file
	  (ok, file) = fseek file 0 FSeekSet 
	| not ok = abort "fseek failed"
	# (data, file) = freads file filesize
	  (ok, world) = fclose file world
	| not ok = abort "fclose failed"
	= (data, world)
	
fileExistsInDynamicPath :: !String !*World -> (!Bool, !*World)
fileExistsInDynamicPath name world
	# (ok, file, world) = fopen (GetDynamicLinkerPath +++ name) FReadData world
	| not ok = (False, world)
	# (ok, world) = fclose file world
	| not ok = abort "fclose failed"
	= (True, world)

writeFileInDynamicPath :: !String !String !*World -> *World
writeFileInDynamicPath name data world
	# (ok, file, world) = fopen (GetDynamicLinkerPath +++ name) FWriteData world
	| not ok = abort "fopen failed"
	# file = fwrites data file
	  (ok, world) = fclose file world
	| not ok = abort "fclose failed"
	= world
