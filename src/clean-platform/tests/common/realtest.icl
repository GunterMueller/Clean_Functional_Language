module realtest

import StdEnv
import Data.Real
import Gast
import Gast.CommandLine

/* These tests and the values for epsilon are taken from
 * https://floating-point-gui.de/errors/comparison/ and adapted to doubles.
 */

MinValue :== IF_INT_64_OR_32 (longBitsToDouble64 0x1) (longBitsToDouble32 (0x1, 0x0))

nearlyEqual :: (!Real !Real -> Bool)
nearlyEqual = approximatelyEqual 0.00001

longBitsToDouble64 :: !Int -> Real
longBitsToDouble64 r = code { no_op }

longBitsToDouble32 :: !(!Int, !Int) -> Real
longBitsToDouble32 _ = code {
		.d 0 2 r
			jmp _convert_double_in_int_to_double32_
		.o 0 2 r
			:_convert_double_in_int_to_double32_
	}

Start w = exposeProperties [] []
	[ name "Regular large numbers"
		[ True  =.= nearlyEqual 1000000.0 1000001.0
		, False =.= nearlyEqual 10000.0 10001.0
		]
	, name "Negative large numbers"
		[ True  =.= nearlyEqual -1000000.0 -1000001.0
		, False =.= nearlyEqual -10000.0 -10001.0
		]
	, name "Numbers around 1.0"
		[ True  =.= nearlyEqual 1.0000001 1.0000002
		, False =.= nearlyEqual 1.0002 1.0001
		]
	, name "Numbers around -1"
		[ True  =.= nearlyEqual -1.000001 -1.000002
		, False =.= nearlyEqual -1.0001 -1.0002
		]
	, name "Numbers between 1.0 and 0.0"
		[ True  =.= nearlyEqual 0.000000001000001 0.000000001000002
		, False =.= nearlyEqual 0.000000000001002 0.000000000001001
		]
	, name "Numbers between -1 and 0.0"
		[ True  =.= nearlyEqual -0.000000001000001 -0.000000001000002
		, False =.= nearlyEqual -0.000000000001002 -0.000000000001001
		]
	, name "Small differences away from zero"
		[ True  =.= nearlyEqual 0.3 0.30000003
		, True  =.= nearlyEqual -0.3 -0.30000003
		]
	, name "Comparisons involving zero"
		[ True  =.= nearlyEqual 0.0 0.0
		, True  =.= nearlyEqual 0.0 -0.0
		, True  =.= nearlyEqual -0.0 -0.0
		, False =.= nearlyEqual 0.00000001 0.0
		, False =.= nearlyEqual -0.00000001 0.0

		, True  =.= approximatelyEqual 0.01 0.0 1E-310
		, False =.= approximatelyEqual 0.000001 1E-310 0.0 

		, True  =.= approximatelyEqual 0.1 0.0 -1E-310
		, False =.= approximatelyEqual 0.00000001 -1E-310 0.0
		]
	, name "Comparisons involving extreme values (overflow potential)"
		[ True  =.= nearlyEqual LargestReal LargestReal
		, False =.= nearlyEqual LargestReal (~LargestReal)
		, False =.= nearlyEqual LargestReal (LargestReal / 2.0)
		, False =.= nearlyEqual LargestReal (~LargestReal / 2.0)
		, False =.= nearlyEqual (~LargestReal) (LargestReal / 2.0)
		]
	, name "Comparisons involving infinities"
		[ True  =.= nearlyEqual Infinity Infinity
		, True  =.= nearlyEqual (~Infinity) (~Infinity)
		, False =.= nearlyEqual (~Infinity) Infinity
		, False =.= nearlyEqual Infinity LargestReal
		, False =.= nearlyEqual (~Infinity) (~LargestReal)
		]
	, name "Comparisons of numbers on opposite sides of 0.0"
		[ False =.= nearlyEqual 1.000000001 -1.0
		, False =.= nearlyEqual -1.000000001 1.0
		, True  =.= nearlyEqual (10.0 * MinValue) (10.0 * (~MinValue))
		, False =.= nearlyEqual (100000000000.0 * MinValue) (100000000000.0 * (~MinValue))
		]
	, name "The really tricky part - comparisons of numbers very close to zero"
		[ True  =.= nearlyEqual MinValue MinValue
		, True  =.= nearlyEqual MinValue (~MinValue)
		, True  =.= nearlyEqual MinValue 0.0 
		, True  =.= nearlyEqual (~MinValue) 0.0 
		, False =.= nearlyEqual 0.000000001 (~MinValue)
		, False =.= nearlyEqual 0.000000001 MinValue
		]
	] w
