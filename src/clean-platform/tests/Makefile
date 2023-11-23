ifeq ($(WINDOWS),1)
CHECKTEST=0
SKIP_PREPARE=1
override CLMFLAGS+=-dynamics
else
CHECKTEST?=1
SKIP_PREPARE?=0
override CLMFLAGS+=-dynamics -aC,-h,200m,-s,2m
endif

CLM:=clm
COLLECTIONS?=OS-Posix OS-Linux OS-Linux-64 Platform-x86
CLMLIBS:=\
	-I ../src/libraries/OS-Independent\
	-I ../src/libraries/OS-Independent/Deprecated/ArgEnv\
	-I ../src/libraries/OS-Independent/Deprecated/Generics\
	-I ../src/libraries/OS-Independent/Deprecated/MersenneTwister\
	-I ../src/libraries/OS-Independent/Deprecated/StdLib\
	$(addprefix -I ../src/libraries/,$(COLLECTIONS))\
	-IL Dynamics\
	-IL GraphCopy\
	-IL TCPIP\
	-IL Gast
ifneq ($(WINDOWS),1)
CLMLIBS+=\
	-l -lmariadb\
	-l -lsqlite3\
	-l -lsnappy
endif

imports_common: prepare
ifneq ($(CHECKTEST),0)
	./checktest $@.icl OS-Independent
endif
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@

imports_posix: prepare
ifneq ($(CHECKTEST),0)
	./checktest $@.icl OS-Posix
endif
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@

imports_linux: prepare
ifneq ($(CHECKTEST),0)
	./checktest $@.icl OS-Linux
endif
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@

imports_linux_32: prepare
ifneq ($(CHECKTEST),0)
	./checktest $@.icl OS-Linux-32
endif
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@

imports_linux_64: prepare
ifneq ($(CHECKTEST),0)
	./checktest $@.icl OS-Linux-64
endif
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@

imports_windows: prepare
ifneq ($(CHECKTEST),0)
	./checktest $@.icl OS-Windows
endif
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@

imports_windows_64: prepare
ifneq ($(CHECKTEST),0)
	./checktest $@.icl OS-Windows-64
endif
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@

imports_x86: prepare
ifneq ($(CHECKTEST),0)
	./checktest $@.icl Platform-x86
endif
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@

prepare:
ifeq ($(SKIP_PREPARE),1)
	@echo "Skipping prepare step..."
else
	$(CLM) $(CLMLIBS) -PABC StdEnv
	$(CLM) $(CLMLIBS) -PABC StdMaybe
	$(CLM) $(CLMLIBS) -PABC -dynamics _SystemDynamic
	$(CLM) $(CLMLIBS) -PABC TCPIP
	$(CLM) $(CLMLIBS) -PABC Gast
	find ../src/libraries -name '*.abc' -exec rm {} \;
endif

.PHONY: prepare
