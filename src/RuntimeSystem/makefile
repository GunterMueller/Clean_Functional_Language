
SDIR=D:\John\Clean2.0\RuntimeSystem\

istartup.b: $(SDIR)istartup.s $(SDIR)icopy.s $(SDIR)imark.s $(SDIR)icompact.s
	copy $(SDIR)istartup.s $(SDIR)istartup.cpp
        gcc -E -D_WINDOWS_ -DWRITE_HEAP -I $(SDIR) $(SDIR)istartup.cpp -o istartup.b
        w

istartup.a: istartup.b a.sed
        sed -f a.sed < istartup.b > istartup.a
        w

iprofile.b: $(SDIR)iprofile.s
	copy $(SDIR)iprofile.s $(SDIR)iprofile.cpp
        gcc -E -D_WINDOWS_ -I $(SDIR) $(SDIR)iprofile.cpp -o iprofile.b
        w

iprofile.a: iprofile.b a.sed
        sed -f a.sed < iprofile.b > iprofile.a
        w

wcon.s: $(SDIR)wcon.c $(SDIR)iwrite_heap.c
        gcc -S -O -Wall -DWINDOWS -DWRITE_HEAP -o wcon.s $(SDIR)wcon.c

wcon.a: wcon.s c.sed
        sed -f c.sed <wcon.s >wcon.a

wcon.o: wcon.a
        as wcon.a -o wcon.o

wcon_imports.a: $(SDIR)wcon_imports.s
	copy $(SDIR)wcon_imports.s $(SDIR)wcon_imports.cpp
	gcc -E -D_WINDOWS_ $(SDIR)wcon_imports.cpp -o wcon_imports.a
	w

iwrite_heap.s: $(SDIR)iwrite_heap.c
        gcc -S -O -Wall -DWINDOWS -o iwrite_heap.s $(SDIR)iwrite_heap.c

iwrite_heap.a: iwrite_heap.s c.sed
        sed -f c.sed <iwrite_heap.s >iwrite_heap.a

iwrite_heap.o: iwrite_heap.a
        as wcon.a -o wcon.o

_startup1.s: istartup.a wcon.a wcon_imports.a
        cp istartup.a _startup1.s
        type wcon_imports.a >> _startup1.s
        type wcon.a >> _startup1.s

_startup1.go: _startup1.s
        as _startup1.s -o _startup1.go

_startup1.o: _startup1.go
        fixgnuasobj _startup1.go _startup1.o

$(SDIR)ifileIO3.a: $(SDIR)ifileIO3.s a.sed
        sed -f a.sed < $(SDIR)ifileIO3.s > $(SDIR)ifileIO3.a
        w

ifileIO3_.s: $(SDIR)ifileIO3.a
	copy $(SDIR)ifileIO3.a $(SDIR)ifileIO3.cpp
        gcc -E -D_WINDOWS_ $(SDIR)ifileIO3.cpp -o ifileIO3_.s
        w

ifileIO3.o: $(SDIR)ifileIO3_.s
        as $(SDIR)ifileIO3_.s -o ifileIO3.o

wfileIO3.a: $(SDIR)wfileIO3.c
        gcc -S -O -Wall -DWINDOWS -o wfileIO3.a $(SDIR)wfileIO3.c

wfileIO3.s: wfileIO3.a c.sed
        sed -f c.sed <wfileIO3.a >wfileIO3.s

wfileIO3.o: wfileIO3.s
        as wfileIO3.s -o wfileIO3.o

_startup2.s: ifileIO3_.s wfileIO3.s
        cp ifileIO3_.s _startup2.s
        type wfileIO3.s >> _startup2.s

_startup2.go: _startup2.s
        as _startup2.s -o _startup2.go

_startup2.o: _startup2.go
        fixgnuasobj _startup2.go _startup2.o

