implementation module LoesListColl

import LoesColl, LoesListSeq
import StdInt
from StdOverloadedList import IsMemberM, RemoveMemberM, ||

instance CollX [] a | == a
where
	Insert x xs = InsertM x xs
	Delete x xs = RemoveMemberM x xs
	IsMember x xs = IsMemberM x xs
	CountMember x xs = CountMemberM x xs

instance CollX [! ] a | == a
where
	Insert x xs = InsertM x xs
	Delete x xs = RemoveMemberM x xs
	IsMember x xs = IsMemberM x xs
	CountMember x xs = CountMemberM x xs

instance CollX [ !] a | == a
where
	Insert x xs = InsertM x xs
	Delete x xs = RemoveMemberM x xs
	IsMember x xs = IsMemberM x xs
	CountMember x xs = CountMemberM x xs

instance CollX [!!] a | == a
where
	Insert x xs = InsertM x xs
	Delete x xs = RemoveMemberM x xs
	IsMember x xs = IsMemberM x xs
	CountMember x xs = CountMemberM x xs

instance Coll [] a | == a
where
	Lookup x xs = LookupM x xs

instance Coll [! ] a | == a
where
	Lookup x xs = LookupM x xs

instance Coll [ !] a | == a
where
	Lookup x xs = LookupM x xs

instance Coll [!!] a | == a
where
	Lookup x xs = LookupM x xs

instance uCollX [] a
where
	uInsert x xs = InsertM x xs
	uDelete f xs = uDeleteM f xs

instance uCollX [! ] a
where
	uInsert x xs = InsertM x xs
	uDelete f xs = uDeleteM f xs

instance uCollX [ !] a
where
	uInsert x xs = InsertM x xs
	uDelete f xs = uDeleteM f xs

instance uCollX [!!] a
where
	uInsert x xs = InsertM x xs
	uDelete f xs = uDeleteM f xs

instance uColl [] a | == a
where
	uSearch x xs = uSearchM x xs
	uExtract f xs = uExtractM f xs

instance uColl [! ] a | == a
where
	uSearch x xs = uSearchM x xs
	uExtract f xs = uExtractM f xs

instance uColl [ !] a | == a
where
	uSearch x xs = uSearchM x xs
	uExtract f xs = uExtractM f xs

instance uColl [!!] a | == a
where
	uSearch x xs = uSearchM x xs
	uExtract f xs = uExtractM f xs

instance CollX [#] a | UList a & == a
where
	Insert x xs = InsertM x xs
	Delete x xs = RemoveMemberM x xs
	IsMember x xs = IsMemberM x xs
	CountMember x xs = CountMemberM x xs

instance CollX [#!] a | UTSList a & == a
where
	Insert x xs = InsertM x xs
	Delete x xs = RemoveMemberM x xs
	IsMember x xs = IsMemberM x xs
	CountMember x xs = CountMemberM x xs

instance Coll [#] a | UList, == a
where
	Lookup x xs = LookupM x xs

instance Coll [#!] a | UTSList, == a
where
	Lookup x xs = LookupM x xs

instance uCollX [#] a | UList a
where
	uInsert x xs = InsertM x xs
	uDelete f xs = uDeleteM f xs

instance uCollX [#!] a | UTSList a
where
	uInsert x xs = InsertM x xs
	uDelete f xs = uDeleteM f xs

instance uColl [#] a | UList, == a
where
	uSearch x xs = uSearchM x xs
	uExtract f xs = uExtractM f xs

instance uColl [#!] a | UTSList, == a
where
	uSearch x xs = uSearchM x xs
	uExtract f xs = uExtractM f xs

InsertM x xs :== [|x:xs]

CountMemberM x xs :== count x 0 xs
where
	count y acc [|x:xs] 
		| x == y = count y (acc + 1) xs
		= count y acc xs
	count _ acc _ = acc

LookupM x xs :== lookup x xs
where
	lookup y [|x:xs]
		| x == y = Just y
		= lookup y xs
	lookup _ _ = Nothing

uDeleteM f xs :== delete f xs
where
	delete f [|x:xs]
		# (ok, x) = f x
		| ok = xs
		= [|x:delete f xs]
	delete _ nil = nil

uSearchM x xs :== usearch x xs
where
	usearch y [|x:xs]
		| y == x = (Just x, [|x:xs])
		# (maybe, xs) = usearch y xs
		= (maybe, [|x:xs])
	usearch _ nil = (Nothing, nil)

uExtractM f xs :== uextract f xs
where
	uextract f [|x:xs]
		# (ok, x) = f x
		| ok = (Just x, xs)
		# (maybe, xs) = uextract f xs
		= (maybe, [|x:xs])
	uextract _ nil = (Nothing, nil)
