#!/bin/sh

#Visual studio compiler
VSSETENV="C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat"
COMMAND=`cygpath --unix $COMSPEC`

vscc() { # $1: C .c file path, $2: .obj output path

	vscc_file=`cygpath --absolute --windows "$1"`
	vscc_dir=`dirname "$1"`
	vscc_object_file="$2"
	(cd "$vscc_dir"
	 cat <<EOBATCH | "$COMMAND"
@call "$VSSETENV" amd64
@cl /nologo /GS- /c "$vscc_file" /Fo"$vscc_object_file"
EOBATCH
	)
}

vscc cAsyncIO.c cAsyncIO.obj
vscc hashtable.c hashtable.obj

cp -v cAsyncIO.obj hashtable.obj kernel32 mswsock winsock2 ucrtbase ../../libraries/OS-Windows/Clean\ System\ Files/

