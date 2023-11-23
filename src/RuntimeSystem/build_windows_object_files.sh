
cp istartup.s istartup.cpp
gcc -E -D_WINDOWS_ -DWRITE_HEAP istartup.cpp -o istartup.b
sed -f a.sed < istartup.b > istartup.a

gcc -S -O -Wall -DWINDOWS -o iwrite_heap.s iwrite_heap.c
sed -f c.sed <iwrite_heap.s >iwrite_heap.a

gcc -S -O -Wall -DWINDOWS -DWRITE_HEAP -o wcon.s wcon.c
sed -f c.sed <wcon.s >wcon.a

cp wcon_imports.s wcon_imports.cpp
gcc -E -D_WINDOWS_ wcon_imports.cpp -o wcon_imports.a

cat istartup.a wcon_imports.a wcon.a > _startup1.s
as _startup1.s -o _startup1.go
chmod +x ./fixgnuasobj.exe
./fixgnuasobj.exe _startup1.go _startup1.o


sed -f a.sed < ifileIO3.s > ifileIO3.a
cp ifileIO3.a ifileIO3.cpp
gcc -E -D_WINDOWS_ ifileIO3.cpp -o ifileIO3_.s

gcc -S -O -Wall -DWINDOWS -o wfileIO3.a wfileIO3.c
sed -f c.sed <wfileIO3.a >wfileIO3.s

cat ifileIO3_.s wfileIO3.s > _startup2.s
as _startup2.s -o _startup2.go
./fixgnuasobj.exe _startup2.go _startup2.o


cp istartup.s istartup.cpp
gcc -E -DPROFILE -DWRITE_HEAP -D_WINDOWS_ istartup.cpp -o istartup.b
sed -f a.sed < istartup.b > istartup.a

cp iprofile.s iprofile.cpp
gcc -E -D_WINDOWS_ iprofile.cpp -o iprofile.b
sed -f a.sed < iprofile.b > iprofile.a

gcc -S -O -Wall -DWINDOWS -DTIME_PROFILE -DWRITE_HEAP -o wcon.s wcon.c
sed -f c.sed <wcon.s >wcon.a

cat istartup.a iprofile.a wcon.a > _startup1.s
as _startup1.s -o _startup1.go
./fixgnuasobj.exe _startup1.go _startup1Profile.o


cp istartup.s istartup.cpp
gcc -E -DPROFILE -DPROFILE_GRAPH -DWRITE_HEAP -D_WINDOWS_ istartup.cpp -o istartup.b
sed -f a.sed < istartup.b > istartup.a

cp iprofilegraph.s iprofilegraph.cpp
gcc -E -D_WINDOWS_ iprofilegraph.cpp -o iprofilegraph.b
sed -f a.sed < iprofilegraph.b > iprofilegraph.a

gcc -S -O -Wall -DWINDOWS -DTIME_PROFILE -DWRITE_HEAP -o wcon.s wcon.c
sed -f c.sed <wcon.s >wcon.a

cat istartup.a iprofilegraph.a wcon.a > _startup1.s
as _startup1.s -o _startup1.go
./fixgnuasobj.exe _startup1.go _startup1ProfileGraph.o

gcc -c -O -Wall -DWINDOWS -o _startup1ProfileGraphB.o profile_graph.c


cp istartup.s istartup.cpp
gcc -E -DPROFILE -DWRITE_HEAP -D_WINDOWS_ istartup.cpp -o istartup.b
sed -f a.sed < istartup.b > istartup.a

cp itrace.s itrace.cpp
gcc -E -D_WINDOWS_ itrace.cpp -o itrace.b
sed -f a.sed < itrace.b > itrace.a

gcc -S -O -Wall -DWINDOWS -DTIME_PROFILE -DWRITE_HEAP -o wcon.s wcon.c
sed -f c.sed <wcon.s >wcon.a

cat istartup.a itrace.a wcon.a > _startup1.s
as _startup1.s -o _startup1.go
./fixgnuasobj.exe _startup1.go _startup1Trace.o
