module DSVIS2005

/**	This module contains the examples that have been given in the DSVIS 2005 paper.
*/

import StdEnv, StdIO
import StdGEC

derive defval Family, CivilStatus, Gender, Maybe, (,), [], NoObject, YesObject, Person, Kids
derive gGEC CivilStatus, Gender

// This Example shows how one can make specialize editors for user defined types
// The default view of a type can be overwritten with a user defined view
// one simply defines a bimap from the original type to an AGEC of that type

Start:: *World -> *World
Start world = startGEC myeditor world

myeditor = startCircuit (feedback mycircuit) defaultv
where
	mycircuit =  edit "Family Tree Editor" 

//	defaultv = (1 <-> 2 ) <^|^> 3

	defaultv :: Family
	defaultv =  defval`

:: Family		=	Family Person CivilStatus (Maybe (Person,Kids))
:: CivilStatus	=	Married | Single
:: Kids			=	Kids [Family]
:: Person	 	= 	Person Gender String 						
:: Gender		=	Male | Female

//derive gGEC Family, Kids, Person, Maybe


gGEC{|Family|} gecArgs pSt 
	= Specialize defval` familyAGEC gecArgs pSt

familyAGEC :: Family -> AGEC Family
familyAGEC f = mkAGEC (to_BimapGEC bimapFamily f) "Family"
where
	bimapFamily = {map_to = toView, map_from = toDomain}

	toView (Family p1 Single _) 			= p1 <^*> Nothing         <*|> Single <|*|> Nothing
	toView (Family p1 any Nothing)          = p1 <^*> Just (other p1) <*|> any    <|*|> Just (Kids [])
	toView (Family p1 any (Just (p2,kids)))	= p1 <^*> Just p2 	      <*|> any    <|*|> Just kids

	toDomain (p1 <^*> Nothing <*|> bs <|*|> _	)			= Family p1 bs Nothing
	toDomain (p1 <^*> Just p2 <*|> bs <|*|> (Just kids))	= Family p1 bs (Just (p2,kids))

	other :: Person -> Person
	other (Person Female _) = Person Male   ""
	other (Person Male   _) = Person Female ""

gGEC{|Kids|} gecArgs pSt 
	= Specialize (Kids []) kidsAGEC gecArgs pSt

kidsAGEC :: Kids -> AGEC(Kids)
kidsAGEC p = mkAGEC (to_BimapGEC bimapKids p) "Kids" 
where
	bimapKids = {map_to = toView, map_from = toDomain}
	where
		toView   (Kids fs)       = displaykids (length fs) <|*|> hor2listAGEC initFamily (number fs)
		toDomain (_ <|*|> alist) = case ^^alist of list -> Kids (unnumber list)

		initFamily = Text "  1:" <^*> (Family (Person Male "") Single Nothing)

		displaykids n = Display (toString n +++ " Child" +++ if (n==1) " " "ren ")

		number   kids = [(Text (toString i +++ ":") <^*> kid) \\ i <- [1..] & kid <- kids]
		unnumber kids = [kid \\ (_ <^*> kid) <- kids]

gGEC{|Person|} gecArgs pSt 
	= Specialize (Person Male "") personAGEC gecArgs pSt
where
	personAGEC :: Person -> AGEC(Person)
	personAGEC p = mkAGEC (to_BimapGEC bimapPerson p) "Partner" 
	where
		bimapPerson = {map_to = toView, map_from = toDomain}

		toView   (Person gender name) = name <*|> gender
		
		toDomain (name <*|> gender)   = Person gender name


// additional hacking conversions funcions just to hide constructors on one level

gGEC{|Maybe|} geca gecArgs pSt 
= Specialize Nothing (MaybeAGEC (gGEC{|*->*|} (gGEC{|*->*|} (gGEC{|*->*|} geca)))) gecArgs pSt
where
	MaybeAGEC :: (TgGEC (NoObject [YesObject a]) (PSt .ps)) (Maybe a) -> AGEC (Maybe a)
	MaybeAGEC gecspec n = mkxAGEC gecspec (to_BimapGEC bimapMaybe Nothing) "Maybe"
	where
		bimapMaybe = {map_to = map_to, map_from = map_from}
		where
			map_to (Nothing) =  NoObject [] 
			map_to (Just a)  =  NoObject [YesObject a]
	
			map_from (NoObject [])  		 = Nothing
			map_from (NoObject [YesObject a]) = Just a


// default values generator

generic defval a ::  a 
defval{|Int|}  				= 0
defval{|Real|}  			= 0.0
defval{|String|}  			= ""
defval{|UNIT|} 			 	= UNIT
defval{|EITHER|} dl dr  	= RIGHT  dr
defval{|PAIR|}   dl dr  	= PAIR   dl dr
defval{|CONS|}   dc     	= CONS   dc
defval{|FIELD|}  df     	= FIELD  df
defval{|OBJECT|} do     	= OBJECT do
defval{|AGEC|}   da 	    = undef

defval` = defval{|*|}


// The set equality example
import GenEq

::	Set a = SetC [a]

gEq{|Set|} eqElt (SetC aElts) (SetC bElts) = eqSet eqElt aElts bElts
where
	eqSet :: (a -> .(b -> .Bool)) .[a] .[b] -> Bool
	eqSet eqf [] bs		= isEmpty bs
	eqSet eqf as []		= False
	eqSet eqf [a:as] bs	= found && eqSet eqf as bs`
	where
		(found,bs`)		= removeWith eqf a bs
		
		removeWith :: (a -> .(b -> .Bool)) a u:[b] -> (.Bool,v:[b]), [u <= v]
		removeWith eqf x []
						= (False,[])
		removeWith eqf x [y:ys]
			| eqf x y	= (True,ys)
			| otherwise	= (found,[y:ys`])
		where
			(found,ys`)	= removeWith eqf x ys

