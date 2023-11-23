definition module Ext_deltaIOState;

from StdFile import class FileSystem;
from deltaIOState import class FileEnv, instance FileEnv (IOState s), ::IOState;

instance FileSystem (IOState s);
