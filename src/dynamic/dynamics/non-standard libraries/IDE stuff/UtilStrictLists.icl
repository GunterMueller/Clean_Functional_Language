implementation module UtilStrictLists

import StdClass,StdString, StdInt, StdMisc,StdArray, StdList;

//	A strict list data structure

::	List t	=	(:!) infixr 0 !t !(List t)
			|	Nil
			
instance toString (List a) | toString a
where
	toString Nil	= "[]"
	toString (h:!t)	= "[" +++ toString h +++ toS t +++ "]"
	where
		toS Nil = ""
		toS (h:!t) = "," +++ toString h +++ toS t

// General operations on lists

Singleton :: !(List t) -> t;
Singleton (x:!Nil) =  x;
	
IsEmptyList	:: !(List t) -> Bool;
IsEmptyList Nil =  True;
IsEmptyList xs 	=  False;
	
Head :: !(List t) -> t;
Head (h:!t)	= h;
Head list	= abort "Head: Empty list";
	
Concat	:: !(List .t) !u:(List .t) -> u:List .t;
Concat (x:!xs)	ys
	#! xs = Concat xs ys;
	= 	x :! xs;
//	= 	x :! Concat xs ys;
Concat Nil		ys	= 	ys;
	
Reverse	:: !(List t) -> List t;
Reverse l =  Reverse2 l Nil;
	
Reverse2 :: !(List .a) u:(List .a) -> v:List .a, [u <= v];
Reverse2 Nil	rev =  rev;
Reverse2 (f:!r)	rev	=  Reverse2 r (f:!rev);
	
LLength	:: !(List t) -> Int;
LLength l =  Length2 0 l;
	
Length2	:: !Int !(List t) -> Int;
Length2 n Nil	=  n;
Length2 n (f:!r) =  Length2 (inc n) r;
		
MapR :: !(s -> t) !(List s) -> List t;
MapR f list	= MapR2 f list Nil;

MapR2 :: (s -> t) !(List s) !(List t) -> List t;
MapR2 f Nil		acc	= acc;
MapR2 f (x:!xs)	acc = MapR2 f xs (f x :! acc);

Filter :: (s -> Bool) !(List s) -> List s;
Filter _ Nil
	=	Nil;
Filter p (h :! t)
	| p h
		=	h :! Filter p t;
	// otherwise
		=	Filter p t;

FilterR :: (s -> Bool) !(List s) -> List s;
FilterR p list = FilterR2 p list Nil;

FilterR2 :: (s -> Bool) !(List s) !(List s) -> List s;
FilterR2 p Nil		acc			= acc;
FilterR2 p (x:!xs)	acc | p x	= FilterR2 p xs (x:!acc);
								= FilterR2 p xs acc;
	
Append :: !(List t) !t -> List t;
Append Nil		x =  x:!Nil;
Append (f:!r)	x =  f :! Append r x;

Select :: !(List t) !Int -> t;
Select (f:!r) 0 = f;
Select (f:!r) i = Select r (dec i);
Select list  i = abort "Select: index out of range";

Update2	:: !(List (List t)) !Int !Int !t -> List (List t);
Update2 (f:!r) 0 j x = Update_new f j x :! r;
Update2 (f:!r) i j x = f :! Update2 r (dec i) j x;
Update2 list  i j x = abort "Update2: index out of range";
	
Update_new :: !(List t) !Int !t -> List t;
Update_new (f:!r) 0 x = x :! r;
Update_new (f:!r) i x = f :! Update_new r (dec i) x;
Update_new list  i x =  abort "Update: index out of range";
 							
AppendLists :: !(List .a) u:(List .a) -> v:List .a, [u <= v];
AppendLists Nil l2 = l2; 
AppendLists (h:!t) l2 = h :! (AppendLists t l2);

FlattenList :: !(List (List .a)) -> List .a;
FlattenList (h:!t)	= AppendLists h (FlattenList t);
FlattenList Nil		= Nil;

P_MapR :: !(s -> (t,Bool)) !(List s) -> (!List t,!Bool)
P_MapR f Nil
	=	(Nil, True)
P_MapR f (x:!xs)
	# (fx,b) = f x
	=	P_MapR2 b f xs fx Nil
where
	P_MapR2 :: !Bool !(s -> (t,Bool)) !(List s) !t !(List t) -> (!List t,!Bool)
	P_MapR2 unchanged f Nil		first acc
		= (first:!acc, unchanged)
	P_MapR2 unchanged f (x:!xs)	first acc
		# (fx,b) = f x
		= P_MapR2 (unchanged && b) f xs first (fx:!acc)

//
// Operations on (ordered) lists of strings
//

InsertStringInList :: !String !(List String) -> List String;
InsertStringInList name Nil
	=  name:!Nil;
InsertStringInList name list=:(nm:!rest)
	| nm < name	=	nm :! InsertStringInList name rest;
	| nm == name	=	list;
					=	name :! nm :! rest;

UnionStringList	:: !(List String) !( List String) -> (List String);
UnionStringList	Nil			ys			=  ys;
UnionStringList	xs			Nil			=  xs;
UnionStringList	xl=:(x:!xs)	yl=:(y:!ys)
	| x < y	=	x :! UnionStringList xs yl;
	| x > y	=	y :! UnionStringList xl ys;
			=	x :! UnionStringList xs ys;

StringOccurs :: !String !.(List String) -> Bool;
StringOccurs s Nil 					=  False;
StringOccurs s (x:!xs)	| x == s	=  True;
									=  StringOccurs s xs;
									
//	Sort a list of strings
/*
SortStrings	:: !(List String) -> List String;
SortStrings (hd :! tl)	=  first :! SortStrings rest;
	where 
		(first,rest)= RemoveFirstString hd tl;

		RemoveFirstString :: !String !(List String) -> (!String, !List String);
		RemoveFirstString first (str :! rest)
			| first < str	= (first1, str   :! rest1);
			| first == str	= (first1, rest1);
							= (first2, first :! rest2);
			where 
				(first1,rest1)= RemoveFirstString first rest;
				(first2,rest2)= RemoveFirstString str   rest;
			
		RemoveFirstString first Nil
							=  (first, Nil);
	
SortStrings Nil			=  Nil;
*/
import StdEnv
SortStrings	:: !.(List String) -> .List String;
SortStrings l = ListToStrictList (sort (StrictListToList l))
/*
sort::!u:[a] -> u:[a] | Ord a
sort l = Head (msort (pair l)) // mergesort
where
	pair (x1 :! x2 :! xs)
		| x2<x1
			= [[x2,x1]:pair xs];
			= [[x1,x2]:pair xs];
	pair x = [x];

	msort [x1,x2:xs] = msort (merge_stage [x1,x2:xs]);
	msort x	= x;

	merge_stage [xs1,xs2:xxs] = [merge xs1 xs2 : merge_stage xxs];
	merge_stage x = x;
*/
					
// Compares two sorted lists of strings

EQStrings :: !(List String) !(List String) -> Bool;
EQStrings Nil		Nil						= True;
EQStrings (a:!resta)	(b:!restb)	| a==b	= EQStrings resta restb;
											= False;
EQStrings _			_						= False;

InclString :: !String !(List String) -> List String
InclString new strs | StringOccurs new strs	= strs
											= new:!strs

RemoveDup :: !.(List a) -> .(List a) | Eq a
RemoveDup (x:!xs) = (x:!RemoveDup (Filter ((<>) x) xs))
RemoveDup _      = Nil

RemoveStringFromList :: !String !(List String) -> List String;
RemoveStringFromList name Nil
	=  Nil;
RemoveStringFromList name (nm:!rest)
	| nm==name
		= rest;
		= nm :! RemoveStringFromList name rest;

RemoveMember :: a !u:(List a) -> v:List a | == a, [u <= v];
RemoveMember e (a:!as)
	| a==e		= as
				= (a:!RemoveMember e as)
RemoveMember e Nil = Nil

RemoveMembers :: !u:(List a) !.(List a) -> v:List a | == a, [u <= v];
RemoveMembers x Nil		= x
RemoveMembers x (b:!y)	= RemoveMembers (RemoveMember b x) y

// Converts a string into a number

StringToInt	:: !String -> Int;
StringToInt string =  TextToNumber string 0;

TextToNumber :: !String !Int -> Int;
TextToNumber ""	n				=  n;
TextToNumber s	n	| isdigit	=  number;
								=  n;
	where 
	number		= TextToNumber (s % (1, dec (size s))) ( 10 * n  + d);
	(isdigit,d)	= Digit (s .[ 0]);
	

Digit :: !Char -> (!Bool, !Int);
Digit '0'  =  (True, 0); 	  Digit '1' =  (True, 1);
Digit '2'  =  (True, 2); 	  Digit '3' =  (True, 3);
Digit '4'  =  (True, 4); 	  Digit '5' =  (True, 5);
Digit '6'  =  (True, 6); 	  Digit '7' =  (True, 7);
Digit '8'  =  (True, 8);	  Digit '9' =  (True, 9);
Digit c	   =  (False,0);

StrictListToList :: !(List .a) -> [.a];
StrictListToList Nil
	=	[];
StrictListToList (h :! t)
	=	[h : StrictListToList t];

ListToStrictList :: ![.a] -> (List .a);
ListToStrictList list
	=	foldr (:!) Nil list; // RWS: wrong line number (change foldr to foldl)

Map	:: !(s -> t) !(List s) -> List t;
Map _ Nil
	=	Nil;
Map f (h :! t)
	=	(f h :! Map f t);
