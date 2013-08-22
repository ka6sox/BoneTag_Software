###########################################################################
#
#	Makefile to build sertest
#
###########################################################################
#MK_OS			= host
#MK_ELF_TARGET 	= sertest
#MK_SRC_FILES = sertest.c
#LDLIBS += -lpthread
#include ../../rules/mkRules.mk


#CROSS_COMPILE?=arm-none-linux-gnueabi-
CFLAGS+= -Wall -D__DEBUG -O2 -mtune=cortex-a8 -march=armv7-a
LDFLAGS+= -lpthread
DEPS = 


all:	sertest

sertest: sertest.o
	$(CROSS_COMPILE)gcc $(CFLAGS) -o $@ $^ $(LDFLAGS)

sertest.o: sertest.c $(DEPS)
	$(CROSS_COMPILE)gcc $(CFLAGS) -c -o $@ $< 


.PHONY: clean

clean:
	rm -rf *.o sertest

