module tartest

import StdFile
import StdFunc
import StdList

import Data.Error
import Data.Functor

import Codec.Archive.Tar

Start w = unTarFile id "_tartest.tar" w
