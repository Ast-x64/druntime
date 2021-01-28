# Makefile to build D runtime library druntime64.lib for Win64

MODEL=64

VCDIR=\Program Files (x86)\Microsoft Visual Studio 10.0\VC
SDKDIR=\Program Files (x86)\Microsoft SDKs\Windows\v7.0A

DMD_DIR=..\dmd
BUILD=release
OS=windows
DMD=$(DMD_DIR)\generated\$(OS)\$(BUILD)\$(MODEL)\dmd

CC="$(VCDIR)\bin\amd64\cl"
LD="$(VCDIR)\bin\amd64\link"
AR="$(VCDIR)\bin\amd64\lib"
CP=cp

DOCDIR=doc
IMPDIR=import

MAKE=make

DFLAGS=-m$(MODEL) -conf= -O -release -dip1000 -inline -w -Isrc -Iimport
UDFLAGS=-m$(MODEL) -conf= -O -release -dip1000 -w -Isrc -Iimport
DDOCFLAGS=-conf= -c -w -o- -Isrc -Iimport -version=CoreDdoc

#CFLAGS=/O2 /I"$(VCDIR)"\INCLUDE /I"$(SDKDIR)"\Include
CFLAGS=/Z7 /I"$(VCDIR)"\INCLUDE /I"$(SDKDIR)"\Include

DRUNTIME_BASE=druntime$(MODEL)
DRUNTIME=lib\$(DRUNTIME_BASE).lib
GCSTUB=lib\gcstub$(MODEL).obj

# do not preselect a C runtime (extracted from the line above to make the auto tester happy)
CFLAGS=$(CFLAGS) /Zl

DOCFMT=

target : import copydir copy $(DRUNTIME) $(GCSTUB)

$(mak\COPY)
$(mak\DOCS)
$(mak\IMPORTS)
$(mak\SRCS)

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)

OBJS= errno_c_$(MODEL).obj msvc_$(MODEL).obj msvc_math_$(MODEL).obj
OBJS_TO_DELETE= errno_c_$(MODEL).obj msvc_$(MODEL).obj msvc_math_$(MODEL).obj

######################## Header file generation ##############################

import:
	"$(MAKE)" -f mak/WINDOWS import DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=$(MODEL) IMPDIR="$(IMPDIR)"

copydir:
	"$(MAKE)" -f mak/WINDOWS copydir HOST_DMD="$(HOST_DMD)" MODEL=$(MODEL) IMPDIR="$(IMPDIR)"

copy:
	"$(MAKE)" -f mak/WINDOWS copy DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=$(MODEL) IMPDIR="$(IMPDIR)"

################### C\ASM Targets ############################

errno_c_$(MODEL).obj : src\core\stdc\errno.c
	$(CC) -c -Fo$@ $(CFLAGS) src\core\stdc\errno.c

msvc_$(MODEL).obj : src\rt\msvc.c win64.mak
	$(CC) -c -Fo$@ $(CFLAGS) src\rt\msvc.c

msvc_math_$(MODEL).obj : src\rt\msvc_math.c win64.mak
	$(CC) -c -Fo$@ $(CFLAGS) src\rt\msvc_math.c

################### gcstub generation #########################

$(GCSTUB) : src\gcstub\gc.d win64.mak
	$(DMD) -c -of$(GCSTUB) src\gcstub\gc.d $(DFLAGS)


################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win64.mak
	*$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

# due to -conf= on the command line, LINKCMD and LIB need to be set in the environment
unittest : $(SRCS) $(DRUNTIME)
	*$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest -ofunittest.exe -main $(SRCS) $(DRUNTIME) -debuglib=$(DRUNTIME) -defaultlib=$(DRUNTIME) user32.lib
	unittest

################### Win32 COFF support #########################

# default to 32-bit compiler relative to 64-bit compiler, link and lib are architecture agnostic
CC32=$(CC)\..\..\cl

druntime32mscoff:
	$(MAKE) -f win64.mak "DMD=$(DMD)" MODEL=32mscoff "CC=\$(CC32)"\"" "AR=\$(AR)"\"" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)"

unittest32mscoff:
	$(MAKE) -f win64.mak "DMD=$(DMD)" MODEL=32mscoff "CC=\$(CC32)"\"" "AR=\$(AR)"\"" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)" unittest

################### zip/install/clean ##########################

zip: druntime.zip

druntime.zip: import
	del druntime.zip
	git ls-tree --name-only -r HEAD >MANIFEST.tmp
	zip32 -T -ur druntime @MANIFEST.tmp
	del MANIFEST.tmp

install: druntime.zip
	unzip -o druntime.zip -d \dmd2\src\druntime

clean:
	del $(DRUNTIME) $(OBJS_TO_DELETE) $(GCSTUB)
	rmdir /S /Q $(DOCDIR) $(IMPDIR)

auto-tester-build:
	$(MAKE) -f win64.mak "DMD=$(DMD)" "VCDIR=$(VCINSTALLDIR)" "SDKDIR=$(WindowsSdkDir)" "CC=$(VCBIN_DIR)\cl" "LD=$(VCBIN_DIR)\link" "AR=$(VCBIN_DIR)\lib" target

# Disable unittests for Druntime.
auto-tester-test:
	@echo "Druntime unittests disabled"
