implementation module CDdatabaseHandler

import StdEnv, StdMaybe
import databaseHandler
import StdHtml

instance readDB CD where
	readDB env = readCD_Database env
instance searchDB CDSearch CD where
	searchDB option txt items = searchDatabase option txt items
instance searchOptions CDSearch where
	searchOptions = {options=[("Album",AnyAlbum),("Artist",AnyArtist),("Song",AnySong)]}
instance headersDB CD where
	headersDB
		= { headers = [(Just 140,"Artist"),(Just 400,"Album"),(Just 50,"Year"),(Just 50,"Duration")]
		  , fields  = \cd -> [cd.group,cd.album,toString cd.year,toString cd.totaltime]
		  }
instance extendedInfoDB CD where
	extendedInfoDB
		= { extKey	= \cd -> [["Group:",cd.group],["Album:",cd.album],["Year:",toString cd.year]]
		  , extVal	= \cd -> [["Track "+++toString nr,title,toString playtime] \\ {nr,title,playtime}<-cd.tracks]
		  									++
		  					 [["Total Time","",toString cd.totaltime]]
		  }

derive gForm  CD, Track, Duration, []
derive gUpd   CD, Track, Duration, []
derive gPrint CD, Track, Duration
derive gParse CD, Track, Duration

::	CD_Database :== ItemData CD

readCD_Database	:: !*env -> (![CD_Database],!*env) | FileSystem env
readCD_Database world
	# (cds,world)	= readCD world
	= ([ { item 	= {itemnr = i, instock = 1, prize = max 500 (2000 - (100 * (2005 - cd.year)))}
		 , data 	= cd
		 }
	   \\ cd <- cds & i <- [0..]
	   ]
	  ,world
	  )
where
	max i j = if (i>j) i j

readCD :: !*env -> (![CD],!*env) | FileSystem env
readCD world
    = case readFile "Nummers.dbs" world of									// read Nummers.dbs
        (Nothing,world) 		= abort "Could not read 'Nummers.dbs'.\n"	// failure: report
        (Just inlines,world)	= (convertDB inlines,world)					// read all cds

/*********************************************************************
    Basic operations on Duration:
*********************************************************************/

instance fromString Duration where
    fromString duration_text
        = case [c \\ c<-:duration_text] of
            [m1,m2,':',s1,s2,nl]    = {minutes=digit m1*10+digit m2, seconds=digit s1*10+digit s2}
            [   m2,':',s1,s2,nl]    = {minutes=            digit m2, seconds=digit s1*10+digit s2}
            otherwise               = abort ("fromString: argument "+++duration_text+++" has wrong format.\n")
    where
        digit c = toInt c - toInt '0'
instance toString Duration where
    toString {minutes,seconds}
        = minutes_txt +++ ":" +++ seconds_txt
    where
        minutes_txt = toString minutes
        seconds_txt = if (seconds<=9) ("0"+++toString seconds) (toString seconds)
class toDuration a :: !a -> Duration
instance toDuration String where
    toDuration x = fromString x
instance zero Duration where
    zero = {minutes=0,seconds=0}
instance + Duration where
    (+) {minutes=m1,seconds=s1} {minutes=m2,seconds=s2}
        = {minutes=m1+m2+s/60, seconds=s rem 60}
    where
        s   = s1+s2
instance < Duration where
    (<) {minutes=m1,seconds=s1} {minutes=m2,seconds=s2}
        = m1<m2 || m1==m2 && s1<s2
instance == Duration where
    (==) {minutes=m1,seconds=s1} {minutes=m2,seconds=s2}
        = m1==m2 && s1==s2


/***********************************************************
    Convert list of strings to list of CDs
***********************************************************/

convertDB :: [String] -> [CD]
convertDB lines
    = cds
where
    allRecords      = map (toDBRecord o tl) (groups 7 (drop 7 lines))
    allKeys         = removeDup [(group,cd,year) \\ (group,cd,year,_,_,_) <- allRecords]
    cdRecords       = [filter (\(g,c,y,_,_,_) = g==group && c==cd && y==year) allRecords \\ (group,cd,year) <- allKeys]
    cds             = map toCD cdRecords

::  DBRecord :== (String,String,String,String,String,String)

toDBRecord :: [String] -> DBRecord
toDBRecord [r1,r2,r3,r4,r5,r6] = (noControl r1,noControl r2,noControl r3,noControl r4,noControl r5,noControl r6)

toCD :: [DBRecord] -> CD
toCD cdrs=:[(group,album,year,_,_,_):_]
    = { group       = group
      , album       = album
      , year        = fromString (initstr year)
      , totaltime   = sum (map (\(_,_,_,_,_,t) -> fromString t) cdrs)
      , tracks      = sortBy (\tr1 tr2 = tr1.nr < tr2.nr) [{nr=fromString (initstr nr),title=noControl title,playtime=fromString t} \\ cdr=:(_,_,_,nr,title,t)<-cdrs]
      }

//  groups n [a11,..,a1n,a21,..,a2n,..,am1,..,amn] = [[a11,..,a1n],[a21,..,a2n],..,[am1,..,amn]]
groups :: Int [a] -> [[a]]
groups n as
    | length first_n < n
        = []
    | otherwise
        = [first_n : groups n rest]
where
    (first_n,rest)  = splitAt n as


//  Read from file to list of newline-terminated strings:
readFile :: String !*env -> (!Maybe [String],!*env) | FileSystem env
readFile fileName env
    # (ok,file,env) = sfopen fileName FReadText env
    | not ok        = (Nothing,env)
    | otherwise     = (Just (readLines file),env)
where
    readLines :: File -> [String]
    readLines file
        | sfend file    = []
        | otherwise     = let (line,file1)  = sfreadline file
                          in  [line : readLines file1]

writeFile :: String [String] !*env -> *env | FileSystem env
writeFile fileName lines env
    # (ok,file,env) = fopen fileName FWriteText env
    | not ok        = abort "Could not open file.\n"
    # file          = foldl (flip fwrites) file lines
    # (ok,env)      = fclose file env
    | not ok        = abort "Could not close file.\n"
    | otherwise     = env

writeToStdOut :: [String] !*env -> *env | FileSystem env
writeToStdOut lines env
    # (io,env)  = stdio env
    # io        = foldl (flip fwrites) io lines
    # (_,env)   = fclose io env
    = env

// small utility stuff

initstr :: !String -> String
initstr ""  = ""
initstr txt = txt%(0,size txt-2)

instance fromString Int where fromString txt = toInt txt
concat strs = foldr (+++) "" strs

noControl string 	= {if (isControl s) ' ' s \\ s <-: string }	

searchDatabase :: CDSearch String [CD_Database] -> (Bool,[CD_Database])
searchDatabase _ "" database
	= (True,database) 
searchDatabase AnyAlbum string database 
	= check database [items \\ items <- database | isSubstring string items.data.album]
searchDatabase AnyArtist string database 
	= check database [items \\ items <- database | isSubstring string items.data.group]
searchDatabase AnySong string database 
	= check database [items \\ items <- database | or [isSubstring string title \\ {title} <- items.data.tracks]]
searchDatabase _ string database
	= (False,[])

check database [] 		 = (False,[])
check database ndatabase = (True,ndatabase)

isSubstring :: String String -> Bool
isSubstring searchstring item
	= compare` [toLower c1 \\ c1 <-: searchstring | isAlphanum c1] [toLower c2 \\ c2 <-: item | isAlphanum c2]
where
	compare` [] _ = True
	compare` ss is
	| length ss > length is = False
	compare` search=:[s:ss] [is:iss]
	| s == is = if (ss == iss%(0,length ss - 1)) True (compare` search iss)
	| otherwise = compare` search iss 
	compare` _ _ = False
