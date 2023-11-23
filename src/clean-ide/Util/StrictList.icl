implementation module StrictList

import StdInt, StdMisc, StdBool

:: StrictList a
	= SCons !a (StrictList a)
	| SNil

instance == (StrictList a) | == a where
  (==) SNil SNil = True
  (==) (SCons x xs) (SCons y ys) = x == y && xs == ys
  (==) _ _ = False

slAppend :: !(StrictList .a) !u:(StrictList .a) -> u:StrictList .a
slAppend SNil			list` = list`
slAppend (SCons x list)	list` = SCons x (slAppend list list`)

slReverse :: !(StrictList a) -> StrictList a
slReverse list = slReverse` list SNil
  where
	slReverse` (SCons head tail) list = slReverse` tail (SCons head list)
	slReverse` SNil				list = list

slSplitAt :: !Int u:(StrictList .a) -> (StrictList .a, u:StrictList .a)
slSplitAt 0 xs = (SNil, xs)
slSplitAt n (SCons x xs) = (SCons x ys, zs)
  where
	(ys, zs) = slSplitAt (n - 1) xs
slSplitAt _ SNil = (SNil, SNil)

slFromList :: ![a] -> StrictList a
slFromList [] = SNil
slFromList [x:xs] = SCons x (slFromList xs)

slMap :: !(a -> b) !(StrictList a) -> StrictList b
slMap _ SNil = SNil
slMap f (SCons x xs) = SCons (f x) (slMap f xs)

slLength :: !(StrictList a) -> Int
slLength list = slLength` list 0
  where
	slLength` (SCons x xs)	len = slLength` xs (len + 1)
	slLength` SNil			len = len

slHead :: !(StrictList a) -> a
slHead (SCons x xs) = x
slHead SNil = abort "slHead (StrictList.icl): empty list\n"

slTail :: !(StrictList a) -> (StrictList a)
slTail (SCons x xs) = xs
slTail SNil = abort "slTail (StrictList.icl): empty list\n"

slToList :: !(StrictList a) -> [a]
slToList SNil = []
slToList (SCons x xs) = [x:slToList xs]

slIndex :: !Int !(StrictList .a) -> .a
slIndex _ SNil		  
  = abort "slIndex (StrictList.icl): index out of range\n"
slIndex 0 (SCons x _)
  = x
slIndex n (SCons x xs) 
  = slIndex (n - 1) xs

slIsEmpty :: !(StrictList a) -> Bool
slIsEmpty SNil = True
slIsEmpty _	  = False

slTake :: !Int !(StrictList a) -> StrictList a
slTake _  SNil = SNil
slTake 0 list = SNil
slTake nr (SCons x xs) = SCons x (slTake (nr-1) xs)

slDrop :: !Int !(StrictList a) -> StrictList a
slDrop _  SNil  = SNil
slDrop 0  list = list
slDrop nr (SCons x xs) = slDrop (nr-1) xs

slLast :: !(StrictList a) -> a
slLast (SCons lastElement SNil) = lastElement
slLast (SCons x xs)			  = slLast xs

slInit :: !(StrictList a) -> StrictList a
slInit (SCons lastElement SNil)	= SNil
slInit (SCons x xs)				= SCons x (slInit xs)

slUpdate :: !Int !.a !u:(StrictList .a) -> u:StrictList .a
slUpdate _ a SNil			= SCons a SNil
slUpdate 0 a (SCons x xs)	= SCons a xs
slUpdate n a (SCons x xs)	= SCons x (slUpdate (n-1) a xs)
