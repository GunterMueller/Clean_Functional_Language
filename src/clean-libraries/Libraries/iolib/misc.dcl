definition module misc;
    
Append :: ![x] !x -> [x];
Concat :: ![x] ![x] -> [x];
Evaluate_2 :: !x !y -> x;
UEvaluate_2 :: !* x !y -> *x;
Evaluate_1 :: !x !y -> y;
Reverse :: ![x] -> [x];
Head :: ![x] -> x;
Minimum :: !Int !Int -> Int;
Maximum :: !Int !Int -> Int;
N :: * x String -> *x;
