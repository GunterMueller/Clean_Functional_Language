implementation module LoesBatchedSeq

import LoesSeq
import StdInt, LoesListSeq

instance Empty (BatchedSeq .a)
where 
	Empty = {front = [|], rear = [|]}

instance uSize (BatchedSeq .a)
where
	uIsEmpty bs=:{front=[|]} = (True, bs)
	uIsEmpty bs = (False, bs)

	uSize {front, rear}
		# (n, front) = uSize front
		  (m, rear) = uSize rear
		= (n + m, {front = front, rear = rear})

instance Fold BatchedSeq a | Foldl BatchedSeq a
where
	Fold f e bs = fold f e bs
	where
		fold f e bs = Foldl f e bs

instance Foldr BatchedSeq a | Foldr [ /*!*/] a
where
	Foldr op r {front, rear} = Foldr op (revFoldr op r rear) front
	where
		revFoldr op r xs = foldr r xs
		where
			foldr r [|] = r
			foldr r [|x:xs] = foldr (op x r) xs

instance Foldl BatchedSeq a | Foldl [ /*!*/] a
where
	Foldl op r {front, rear} = revFoldl op (Foldl op r front) rear
	where
		revFoldl op r xs = foldl r xs
		where
			foldl r [|] = r
			foldl r [|x:xs] = op (foldl r xs) x
	
instance uSeq BatchedSeq a | uSeq [ /*!*/] a
where
	uCons x bs=:{front} = {bs & front = [|x:front]}

	uDeCons bs=:{front=[|]} = (Nothing, bs)
	uDeCons {front=[|x], rear} = (Just x, {front = uReverse rear, rear = [|]})
	uDeCons bs=:{front=[|x:xs]} = (Just x, {bs & front = xs})

	uReverse bs=:{front, rear=[|]} = {bs & front = uReverse front}
	uReverse {front, rear} = {front = rear, rear = front}

instance uDeSeq BatchedSeq a | uDeSeq [ /*!*/] a
where
	uSnoc {front=[|], rear} x = {front = [|x],  rear = rear}
	uSnoc {front, rear} x = {front = front, rear = [|x:rear]}
	
	uDeSnoc bs=:{rear=[|x:xs]} = ({bs & rear = xs}, Just x)
	uDeSnoc bs=:{front}
		# (front, maybe) = uDeSnoc front
		= ({bs & front = front}, maybe)

instance uMap BatchedSeq a b | uMap [ /*!*/] a b
where
	uMap f {front, rear} = {front = uMap f front , rear = uMap f rear}
