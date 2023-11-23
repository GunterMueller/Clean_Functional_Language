module snappytest

import StdEnv
import StdFunc
import Codec.Compression.Snappy
import Codec.Compression.Snappy.Graph
import Data.Error
from Data.Func import $
import System.CommandLine
import System.File
import System.Time

Start :: *World -> *World
Start w = snd $ uncurry fclose $ seq (map uncurry tests) $ stdio w
where
	tests =
		[ test_string
		, test_expr "small_expr" ((==) [0..10]) [0..10]
		, test_expr "large_expr" ((==) [0..10000000]) [0..10000000]
		, test_expr "inf_expr"   ((==) [0..999] o take 1000) [0..]
		, test_expr "func_expr"  ((==) [0,5..50] o flip map [0..10]) ((*) 5)
		]

test_string :: !*File !*World -> *(!*File, !*World)
test_string io w
#! (cmd,w) = getCommandLine w
#! file = if (length cmd >= 2) (cmd!!1) "snappytest.icl"
#! (f,w) = readFile file w
| isError f
	# io = io <<< Failure <<< "Could not open " <<< file <<< "." <<< endl
	= (io, w)
#! data = fromOk f
#! (c1,w) = clock w
#! (compressed,w) = (snappy_compress data,w)
#! (c2,w) = clock w
#! (sd,sc) = (size data, size compressed)
#! io = io <<< Info <<< "string: compressed " <<< sd <<< " bytes to " <<< sc
	<<< " (compression rate " <<< (toReal sd / toReal sc) <<< ")" <<< endl
#! (uncompressed,w) = (snappy_uncompress compressed,w)
#! (c3,w) = clock w
#! (time1,time2) = (c2 - c1, c3 - c2)
#! io = io <<< Info <<< "Compression: " <<< time1 <<< " / " <<<
	(toReal sd / 1000000.0 / toReal time1) <<< "MB/s\r\n" <<<
	"Uncompression: " <<< time2 <<< " / " <<<
	(toReal sc / 1000000.0 / toReal time2) <<< "MB/s" <<< endl
| data <> uncompressed
	# io = io <<< Failure <<< "string: equality not preserved" <<< endl
	= (io, w)
#! io = io <<< Success <<< "string passed" <<< endl
= (io, w)

instance <<< Clock where (<<<) f c = f <<< toReal c <<< "s"
instance - Clock where (-) (Clock a) (Clock b) = Clock (a - b)
instance toReal Clock where toReal (Clock i) = toReal i / toReal CLK_PER_SEC

test_expr :: !String !(a -> Bool) a !*File !*World -> *(!*File, !*World)
test_expr name isOk expr io w
# data = snappy_compress_a expr
# io = io <<< Info <<< name <<< ": compressed to " <<< size data <<< " bytes" <<< endl
# expr` = snappy_uncompress_a data
| not (isOk expr`)
	# io = io <<< Failure <<< name <<< ": equality not preserved" <<< endl
	= (io,w)
# io = io <<< Success <<< name <<< " passed" <<< endl
= (io,w)

:: MessageType = Info | Failure | Success
instance <<< MessageType
where
	(<<<) f Info    = f <<< "\x1B[36m"
	(<<<) f Failure = f <<< "\x1B[31m"
	(<<<) f Success = f <<< "\x1B[32m"

endl =: "\x1B[0m\r\n"
