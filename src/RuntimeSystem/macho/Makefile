
all: _startup.o _startupProfile.o _startupTrace.o _startup2.o _startup3.o _library.o


_startup.o: pstartup_.a
	as pstartup_.a -o _startup.o

pstartup_.a: pstartup.a pmark.a pcompact.a pcompact_rmark.a pcompact_rmarkr.a pcopy.a pmacros.a pap.a
	cpp -DPROFILE=0 pstartup.a > pstartup_.a

pstartup_p.a: pstartup.a pmark.a pcompact.a pcopy.a pmacros.a pap.a
	cpp -DPROFILE=1 pstartup.a > pstartup_p.a


_startupProfile.o: _startupProfile_.a
	as _startupProfile_.a -o _startupProfile.o

_startupProfile_.a: pstartup_p.a pprofile_.a
	cat pstartup_p.a pprofile_.a > _startupProfile_.a

pprofile.o: pprofile_.a
	as pprofile_.a -o pprofile.o

pprofile_.a: pprofile.a
	cpp pprofile.a > pprofile_.a


_startupTrace.o: _startupTrace_.a
	as _startupTrace_.a -o _startupTrace.o

_startupTrace_.a: pstartup_p.a ptrace_.a
	cat pstartup_p.a ptrace_.a > _startupTrace_.a

ptrace.o: ptrace_.a
	as ptrace_.a -o ptrace.o

ptrace_.a: ptrace.a
	cpp ptrace.a > ptrace_.a


_startup2.o: pfileIO3_.a
	as pfileIO3_.a -o _startup2.o

pfileIO3_.a: pfileIO3.a
	cpp pfileIO3.a > pfileIO3_.a


_startup3.o: ../mfileIO3.c
	cc -I /Developer/Headers/FlatCarbon/ -I .. -c -fpascal-strings -O -DMACHO -DMACOSX=1 ../mfileIO3.c -o _startup3.o


_library.o: ../mcon.c ../mcon.h
	cc -I /Developer/Headers/FlatCarbon/ -I .. -c -fpascal-strings -O -DMACHO ../mcon.c -o _library.o


cleanup:
	rm -f pstartup_.a pstartup_p.a _startupTrace_.a _startupProfile_.a pprofile_.a ptrace_.a pfileIO3_.a
