implementation module StdIOBasic


//	********************************************************************************
//	Clean Standard Object I/O library, version 1.2
//	
//	StdIOBasic defines basic types and access functions for the I/O library.
//	********************************************************************************


import	StdBool, StdInt, StdList, StdOverloaded, StdString


/*	General type constructors for composing context-independent data structures.
*/
::	:^:		t1 t2			= (:^:) infixr 9 t1 t2


/*	General type constructors for composing context-dependent data structures.
*/
::	:~:		t1 t2		cs	= (:~:) infixr 9 (t1 cs) (t2 cs)
::	ListCS		t		cs	= ListCS [t cs]
::	NilCS				cs	= NilCS


/*	General type constructors for composing local and context-dependent 
	data structures.
*/
::	:+:		t1 t2	ls	cs	= (:+:) infixr 9 (t1 ls cs) (t2 ls cs)
::	ListLS		t	ls	cs	= ListLS [t ls cs]
::	NilLS			ls	cs	= NilLS
::	NewLS		t	ls	cs	= E..new: {newLS::new, newDef:: t   new		cs}
::	AddLS		t	ls	cs	= E..add: {addLS::add, addDef:: t *(add,ls)	cs}

noLS :: (.a->.b) (.c,.a) -> (.c,.b)
noLS f (c,a) = (c,f a)

noLS1:: (.x->.a->.b) .x (.c,.a) -> (.c,.b)
noLS1 f x (c,a) = (c,f x a)


/*	Frequently occurring data types.					*/

::	Index				:==	Int
::	Title				:==	String
::	Size
	=	{	w			:: !Int
		,	h			:: !Int
		}
::	Vector2
	=	{	vx			:: !Int
		,	vy			:: !Int
		}
::	Point2
	=	{	x			:: !Int
		,	y			:: !Int
		}
::	Rectangle
	=	{	corner1		:: !Point2
		,	corner2		:: !Point2
		}

class toVector x :: !x -> Vector2


instance == Size where
	(==) :: !Size !Size -> Bool
	(==) {w=a,h=b} {w=c,h=d} = a==c && b==d
instance zero Size where
	zero :: Size
	zero = {w=0,h=0}
instance toVector Size where
	toVector :: !Size -> Vector2
	toVector {w,h} = {vx=w,vy=h}
instance toString Size where
	toString :: !Size -> {#Char}
	toString {w,h}
		= curlify (itemsList "," (map recordFieldtoString (zip2 ["w","h"] [w,h])))


instance == Vector2 where
	(==) :: !Vector2 !Vector2 -> Bool
	(==) {vx=a,vy=b} {vx=c,vy=d} = a==c && b==d
instance + Vector2 where
	(+) :: !Vector2 !Vector2 -> Vector2
	(+) {vx=vx1,vy=vy1} {vx=vx2,vy=vy2} = {vx=vx1+vx2,vy=vy1+vy2}
instance - Vector2 where
	(-) :: !Vector2 !Vector2 -> Vector2
	(-) {vx=vx1,vy=vy1} {vx=vx2,vy=vy2} = {vx=vx1-vx2,vy=vy1-vy2}
instance zero Vector2 where
	zero :: Vector2
	zero = {vx=0,vy=0}
instance ~ Vector2 where
	(~) :: !Vector2 -> Vector2
	(~) {vx,vy} = {vx=0-vx,vy=0-vy}
instance toString Vector2 where
	toString :: !Vector2 -> {#Char}
	toString {vx,vy}
		= curlify (itemsList "," (map recordFieldtoString (zip2 ["vx","vy"] [vx,vy])))


instance == Point2 where
	(==) :: !Point2 !Point2 -> Bool
	(==) {x=a,y=b} {x=c,y=d} = a==c && b==d
instance + Point2 where
	(+) :: !Point2 !Point2 -> Point2
	(+) {x=x1,y=y1} {x=x2,y=y2} = {x=x1+x2,y=y1+y2}
instance - Point2 where
	(-) :: !Point2 !Point2 -> Point2
	(-) {x=x1,y=y1} {x=x2,y=y2} = {x=x1-x2,y=y1-y2}
instance zero Point2 where
	zero :: Point2
	zero = {x=0,y=0}
instance ~ Point2 where
	(~) :: !Point2 -> Point2
	(~) {x,y} = {x=0-x,y=0-y}
instance toVector Point2 where
	toVector :: !Point2 -> Vector2
	toVector {x,y}
		= {vx=x,vy=y}
instance toString Point2 where
	toString :: !Point2 -> {#Char}
	toString {x,y}
		= curlify (itemsList "," (map recordFieldtoString (zip2 ["x","y"] [x,y])))

movePoint :: !Vector2 !Point2 -> .Point2
movePoint {vx,vy} {x,y} = {x=vx+x,y=vy+y}


instance == Rectangle where
	(==) :: !Rectangle !Rectangle -> Bool
	(==) {corner1=a,corner2=b} {corner1=c,corner2=d} = a==c && b==d
instance zero Rectangle where
	zero :: Rectangle
	zero = {corner1=zero,corner2=zero}
instance toString Rectangle where
	toString :: !Rectangle -> {#Char}
	toString {corner1,corner2}
		= curlify (itemsList "," (map recordFieldtoString (zip2 ["corner1","corner2"] [corner1,corner2])))

rectangleSize :: !Rectangle -> Size
rectangleSize {corner1={x=x1,y=y1},corner2={x=x2,y=y2}} = {w=abs (x2-x1),h=abs (y2-y1)}


::	IdFun st
	:==	st -> st


//	Some handy functions for toString:
curlify  x = "{"+++x+++"}"

recordFieldtoString :: (String,a) -> String | toString a	// recordFieldtoString f v -> f=v
recordFieldtoString (field,value) = field+++"="+++toString value

itemsList :: !String ![String] -> String	// itemsList c [a0,...an] -> a0 c a1 c ... c an
itemsList separator [x:xs]
	= x+++itemsList` xs
where
	itemsList` [x:xs]	= separator+++x+++itemsList` xs
	itemsList` _		= ""
itemsList _ _
	= ""
