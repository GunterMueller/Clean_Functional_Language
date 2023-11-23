#!/bin/bash
cat ../backend.link64 | tr -d '\r' | sed -e "s/\/EXPORT://" > backend.dllexport_symbols
ctags -x --c-kinds=f backend.c > backend.c_tags
cp backend.c backend_dllexport.c
cat backend.dllexport_symbols | while read in
do
line_n=`grep "$in " backend.c_tags | sed -e "s/ [ ]*/ /g" | cut -d ' ' -f 3`
sed -e "$line_n""s/$in/__declspec(dllexport)$in/" backend_dllexport.c > backend_dllexport_.c
mv backend_dllexport_.c backend_dllexport.c
done
