ifeq ($(WINDOWS),1)
override CLMFLAGS+=-dynamics
else
override CLMFLAGS+=-dynamics -aC,-h,100m
endif

PROJECTDIRS:=socket WebPM asyncio
EXAMPLES:=IPLookup MapDemo ProcessDemo SQLDbDemo WebDemo client server PM networkio
VPATH:=$(PROJECTDIRS)

CLM?=clm
COLLECTIONS?=Platform-x86 OS-Posix OS-Linux OS-Linux-64
CLMLIBS:=\
	-I ../libraries/OS-Independent\
	-I ../libraries/OS-Independent/Deprecated/ArgEnv\
	-I ../libraries/OS-Independent/Deprecated/Generics\
	-I ../libraries/OS-Independent/Deprecated/MersenneTwister\
	-I ../libraries/OS-Independent/Deprecated/StdLib\
	$(addprefix -I ../libraries/,$(COLLECTIONS))\
	$(addprefix -I ,$(PROJECTDIRS))\
	-IL TCPIP\
	-IL Dynamics

all: $(EXAMPLES)

.FORCE:

%: %.icl .FORCE
	$(CLM) $(CLMFLAGS) $(CLMLIBS) $@ -o $@
