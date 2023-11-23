CLM:=clm
CLMFLAGS:=-I ../Libraries -IL Platform -nt -b
DIFF?=diff

TESTS:=bool char int tree with_options
RUN_TESTS:=$(addprefix run_,$(TESTS))

all: $(TESTS)

test: $(RUN_TESTS)

$(filter-out with_options,$(TESTS)): .FORCE
	$(CLM) $(CLMFLAGS) $@ -o $@

with_options: .FORCE
	$(CLM) $(CLMFLAGS) -nr $@ -o $@

$(RUN_TESTS): run_%: %
	./$< | perl -pe 's/.*\r//g' > $<.result
	$(DIFF) $<.expected $<.result

.FORCE:

.PHONY: .FORCE
