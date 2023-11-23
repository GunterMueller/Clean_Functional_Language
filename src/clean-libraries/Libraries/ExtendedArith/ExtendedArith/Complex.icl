implementation module Complex

import StdEnv

:: Complex 
	= { re	:: !Real
	  , im  :: !Real
	  }
	  
:: Polar
	= {	magn	:: !Real
	  ,	phas	:: !Real
	  }

(:+) infix 5
(:+) re im :== { re = re, im = im }

instance + Complex
where	(+) { re = a, im = b } { re = c , im = d } = { re = a+c , im = b+d }

instance - Complex 
where   (-) { re = a, im = b } {re = c, im = d} = { re = a-c, im = b-d }

instance zero Complex
where   zero    = { re = 0.0, im = 0.0 }

instance one Complex 
where   one     = { re = 1.0, im = 0.0 } 
	
instance * Complex 
where   (*) {re = a, im = b} { re = c, im = d}
			# ac	= a*c
			# bd	= b*d
            = {re = ac - bd, im = (a+b)*(c+d)-ac-bd }

instance / Complex
where   (/) {re = a, im = b} {re = c, im = d}
			| abs c < abs d
				# cod	= c/d
				# den	= c*cod+d
				= { re=(a*cod+b)/den , im = (b*cod-a)/den }
			# doc	= d/c
			# den	= c+d*doc
            = {re = (a+b*doc)/den, im = (b-a*doc)/den}

conjugate :: !Complex -> Complex
conjugate { re = a , im = b } = { re = a , im = ~b }

polarToComplex :: !Polar -> Complex 
polarToComplex {magn = m, phas = p} = { re = (m * cos p) , im = (m * sin p)}


complexToPolar :: !Complex -> Polar
complexToPolar c = {magn= (magnitude c),phas= (phase c)}

magnitude :: !Complex -> Real 
magnitude { re = a, im = b} =  sqrt(a*a + b*b)

pi2 =: pi/2.0
pi :== 3.1415926535897932384626433832795028841971693993751058209749445

phase :: !Complex -> Real 
phase { re, im } 
	# im_positive = im>=0.0
	# re_positive = re>=0.0
	| abs re>abs im
		# quot = im/re
		  atan = atan quot
		| im_positive && not re_positive
			= pi+atan
		| not im_positive && not re_positive
			= atan-pi
		= atan
	# quot = re/im
	  atan = atan quot
	| im_positive
		= pi2-atan
	= (~pi2)-atan

cis :: !Real -> Complex
cis theta = {re = cos theta , im = sin theta}

instance ~ Complex
where (~) {re = a , im = b} = { re = ~a , im = ~b}

instance abs Complex 
where abs c = {re = magnitude c , im = zero}

signumC :: !Complex -> Complex 
signumC z=:{ re = a , im = b} 
	| a==zero && b==zero
		= zero
		= { re = a/m , im = b/m}
	where m = magnitude z 

sq x	:== x * x

instance sqrt Complex
where   sqrt {re = c, im = d}
			| c==0.0 && d==0.0
				= zero
			# absc	= abs c
			  absd	= abs d
			  w		= if (absc >= absd) 
							((sqrt absc)*(sqrt ((1.0 + (sqrt (1.0 + sq (d/c))))/2.0)))
							(let cod = c/d in (sqrt absd)*(sqrt ((abs cod + (sqrt (1.0 + sq cod)))/2.0)))
			  do2w	= d/(2.0*w)
			| c >= 0.0
				= { re = w , im = do2w }
			| d >= 0.0
				= { re = (abs do2w) , im = w }
			= { re = (abs do2w), im = ~w }

instance sin Complex 
where	sin { re = a , im = b } = { re = sin a * cosh b , im = cos a * sinh b}

instance cos Complex
where	cos {re = a , im = b} = { re = cos a * cosh b , im = ~(sin a) * sinh b}

instance tan Complex 
where tan c = sin c / cos c

instance sinh Complex 
where	sinh {re = a , im = b} = {re = sinh a * cos b , im = cosh a * sin b}

instance cosh Complex 
where	cosh {re = a , im = b} = {re = cosh a * cos b , im = sinh a * sin b}

instance tanh Complex 
where tanh c = sinh c / cosh c

instance exp Complex 
where	exp { re = r, im = i} = {re = a*cos i, im = a*sin i}
		where	a = exp r

instance ln Complex
where	ln z=:{ re = r, im = i }
				= { re = ln (magnitude z), im = phase z }


instance asin Complex
where 	asin z=:{re = r, im = i} = {re = y1, im = ~x1}
		where	y1 = com.im
				x1 = com.re
				com1 = {re = (~i),im = r} + sqrt(one-z*z) 
                com = ln com1   

instance acos Complex                
where 	acos z=:{re = r, im = i} = {re = y2, im = ~x2}
		where x2 = com.re
			  y2 = com.im
			  x1 = sgy.re
			  y1 = sgy.im
			  sgy = sqrt (one- z*z)
			  com = ln (z + {re = ~y1, im = x1} )
			  
			  
instance atan Complex
where	atan z=:{re = r, im = i} = {re = y1, im = ~x1}
		where x1 = com.re
			  y1 = com.im
			  com = ln ( {re= 1.0-i, im= r} / sqrt (one+z*z) )
 		  
instance asinh Complex
where	asinh z = ln (z + sqrt (one+z*z))

instance acosh Complex
where	acosh z = ln (z + (z+one)* sqrt ((z-one)/(z+one)))

instance atanh Complex
where	atanh z = ln ((one+z)/sqrt(one-z*z))

instance == Complex
where	(==) c1 c2 = c1.re==c2.re && c1.im==c2.im

(:^) infixr 8 :: !Complex !Real -> Complex
(:^) c exp = polarToComplex { magn = (magnitude c)^exp, phas = (phase c)*exp } // deMoivre

realPart :: !Complex -> Real
realPart {re} = re

imagPart :: !Complex -> Real
imagPart {im} = im
