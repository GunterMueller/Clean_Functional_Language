built-in commands:

StdEnv :: *World -> *World // writes a part of Clean's StdEnv to disk
cwd :: [String] // current working directory e.g. ["home","docs"]
path :: [[String]] // list of directories used to search for dynamics
cd :: [String] *World -> *World // changes the current working directory (relative path, use ".." to go up)
ls :: [String] *World -> *World // list give directory (relative path)
mkdir :: [String] *World -> *World // make directory (relative path)
rm :: [String] *World -> *World // remove file (relative path)
rmdir :: [String] *World -> *World // remove empty directory (relative path)
newProcess :: (*World -> *World) *World -> (Int, *World) // start first argument as new process
killProcess :: Int *World -> *World // kill process by id
joinProcess :: Int *World -> *World // wait for process to finish
shutdown :: *World -> *World // kill process server

examples:

> mkdir ["StdEnv"]
> cd ["StdEnv"]
> StdEnv
> cd [".."]
> [["StdEnv"]] >>> path
> ls [] | \list -> case list of [(DynamicDirectory x):xs] -> return xs
> newProcess Esther

syntax examples:

> \x -> x
> [1,3..100]
> fac n = if (n < 2) 1 (n * fac (n - 1))
> fac 10
> let ones = [1:ones] in take 100 ones
> \list -> case list of [] -> True; _ -> False
> mkdir ["test"] ; cd ["test"]

