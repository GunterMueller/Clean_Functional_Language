definition module LoesListColl

import LoesColl, LoesListSeq

instance CollX	[] a | == a, [! ] a | == a, [ !] a | == a, [!!] a | == a
instance Coll	[] a | == a, [! ] a | == a, [ !] a | == a, [!!] a | == a

instance uCollX	[] a, [! ] a, [ !] a, [!!] a
instance uColl	[] a | == a, [! ] a | == a, [ !] a | == a, [!!] a | == a

instance CollX	[#] a | UList, == a, [#!] a | UTSList, == a
instance Coll	[#] a | UList, == a, [#!] a | UTSList, == a

instance uCollX	[#] a | UList a, [#!] a | UTSList a
instance uColl	[#] a | UList, == a, [#!] a | UTSList, == a
