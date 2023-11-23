definition module CDdatabaseHandler

import databaseHandler
import StdHtml

instance readDB                 CD
instance searchDB      CDSearch CD
instance searchOptions CDSearch
instance headersDB              CD
instance extendedInfoDB         CD

::  CD
 =  {   group       :: !Group
    ,   album       :: !Album
    ,   year        :: !Year
	,   totaltime   :: !Duration
   	,   tracks      :: ![Track]
    }
::  Track
 =  {   nr          :: !Int
    ,   title       :: !String
    ,   playtime    :: !Duration
    }
::  Duration
 =  {   minutes     :: !Int
    ,   seconds     :: !Int
    }
::  Group           :== String
::  Album           :== String
::  Year            :== Int

instance toString Duration
::	CDSearch = AnyAlbum | AnyArtist | AnySong

derive gForm  CD, Track, Duration, []
derive gUpd   CD, Track, Duration, []
derive gPrint CD, Track, Duration
derive gParse CD, Track, Duration
