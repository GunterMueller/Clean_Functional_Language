module pi

/* This example program calculates the first d digits of pi
   (warning: under Windows NT you can print only numbers with less than
   approximately 65000 digits */

d =	1000

import StdEnv
import BigInt

arctan :: Int BigInt -> BigInt
arctan n scale
	=	sum` (takeWhile ((<>) zero)
				[scale` /% (sign * m)
					\\	sign <- flatten (repeat [1, -1])
					&	m <- [1,3..]
					&	scale` <- iterate (flip (/%) (n*n)) (scale/%n)
				]
			)

(/%) big small
	:==	big / toBigInt small

sum`
	:==	foldl (+) (toBigInt 0)

pi :: !BigInt -> BigInt
pi scale
	=	arctan 18 (scale*%48) + arctan 57 (scale*%32) - arctan 239 (scale*%20)

Start
	=	toString (pi scale)
	where
		scale
			=	toBigInt 10 ^% d
