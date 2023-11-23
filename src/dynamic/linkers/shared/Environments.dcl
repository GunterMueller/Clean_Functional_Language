definition module Environments;

from StdString import String;

:: Environment :== [(!String,!String)];	

ReplaceEnvironmentVar :: !String !Environment -> !String;
