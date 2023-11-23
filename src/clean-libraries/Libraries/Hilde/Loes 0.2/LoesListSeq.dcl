definition module LoesListSeq

import LoesSeq, StdStrictLists

instance Empty	[.a], [!.a], [.a!], [!.a!]
instance Size	[a], [!a], [a!], [!a!]
instance Fold	[] a, [! ] a, [ !] a, [!!] a
instance Foldl	[] a, [! ] a, [ !] a, [!!] a
instance Foldr	[] a, [! ] a, [ !] a, [!!] a
instance Seq	[] a, [! ] a, [ !] a, [!!] a
instance DeSeq	[] a, [! ] a, [ !] a, [!!] a
instance Map	[] a b, [! ] a b, [ !] a b, [!!] a b

instance uSize	[.a], [!.a], [.a!], [!.a!]
instance uSeq	[] a, [! ] a, [ !] a, [!!] a
instance uDeSeq	[] a, [! ] a, [ !] a, [!!] a
instance uMap	[] a b, [! ] a b, [ !] a b, [!!] a b 

instance Empty	[#.a] | UList a, [#.a!] | UTSList a 
instance Size	[#a] | UList a, [#a!] | UTSList a 
instance Fold	[#] a | UList a, [#!] a | UTSList a 
instance Foldl	[#] a | UList a, [#!] a | UTSList a 
instance Foldr	[#] a | UList a, [#!] a | UTSList a 
instance Seq	[#] a | UList a, [#!] a | UTSList a 
instance DeSeq	[#] a | UList a, [#!] a | UTSList a 
instance Map	[#] a b | UList a & UList b, [#!] a b | UTSList a & UTSList b

instance uSize	[#.a] | UList a, [#.a!] | UTSList a 
instance uSeq	[#] a | UList a, [#!] a | UTSList a 
instance uDeSeq	[#] a | UList a, [#!] a | UTSList a 
instance uMap	[#] a b | UList a & UList b, [#!] a b | UTSList a & UTSList b
