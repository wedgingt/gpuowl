CXXFLAGS = -Wall -g -O3 -std=gnu++17 -I.

ifeq (MSWindows,$(OS))
EXE=gpuowl-win.exe
O=obj
else
ifneq (,$(shell which uname && uname -o 2>>/dev/null | fgrep -i linux))
EXE=gpuowl
O=o
else
ifneq (,$(shell which uname && uname -o 2>>/dev/null | fgrep -i cygwin))
EXE=gpuowl-cygwin.exe
O=obj
else
EXE=gpuowl-win.exe
O=obj
endif
endif
endif

ifeq (yes,$(shell test -d /usr/local/cuda-11 && echo 'yes'))
CUDA_LIBS = -fPIC -L/usr/local/cuda-11/lib64 -lcudart
CUDA_INCL = -I/usr/local/cuda-11/include
endif
ifeq (yes,$(shell test -d /usr/local/cuda-10 && echo 'yes'))
CUDA_LIBS = -fPIC -L/usr/local/cuda-10/lib64 -lcudart
CUDA_INCL = -I/usr/local/cuda-10/include
endif

ifeq (,$(CUDA_LIBS))
# default
CUDA_LIBS = -L/opt/rocm-5.1.1/opencl/lib -L/opt/rocm-4.0.0/opencl/lib -L/opt/rocm-3.3.0/opencl/lib/x86_64 -L/opt/rocm/opencl/lib -L/opt/rocm/opencl/lib/x86_64 -L/opt/amdgpu-pro/lib/x86_64-linux-gnu
endif
ifeq (,$(CUDA_INCL))
CUDA_INCL = -IdefaultCUDA_LIBS
endif

LIBPATH = $(CUDA_LIBS) -L.

LDFLAGS = -lstdc++fs $(LIBPATH) -lgmp -pthread

LINK = $(CXX) $(CXXFLAGS)

SRCS=$(wildcard *.cpp)
OBJS = $(SRCS:%.cpp=%.$(O))
OWL_OBJS=$(filter-out D.$(O) sine_compare.$(O) qdcheb.$(O),$(OBJS))

DEPDIR := .d
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.Td
COMPILE.cc = $(CXX) $(DEPFLAGS) $(CXXFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c
#POSTCOMPILE = @mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d && touch $@

all: .d version.inc gpuowl-wrap.cpp $(EXE)
	echo $@ > $@

gpuowl: $(OWL_OBJS) gpuowl-wrap.$(O)
	$(LINK) $^ -o $@ $(LDFLAGS)

gpuowl-cygwin.exe: $(OWL_OBJS) gpuowl-wrap.$(O)
	$(LINK) -static $^ -o $@ $(LDFLAGS)

gpuowl-win.exe: $(OWL_OBJS) gpuowl-wrap.$(O)
	$(LINK) -static $^ -o $@ $(LDFLAGS)
	strip $@

D:	D.$(O) Pm1Plan.$(O) log.$(O) common.$(O) timeutil.$(O)
	$(LINK) $^ -o $@ $(LDFLAGS)

clean:
	rm -f *.$(O) gpuowl gpuowl-win.exe gpuowl-wrap.cpp
	rm -f all gpuowl-expanded.cl gpuowl-cygwin.exe D
	rm -f version.inc install FORCE clean
	rm -rf $(DEPDIR)

%.o: %.cpp $(DEPDIR)/%.d
	$(COMPILE.cc) $(OUTPUT_OPTION) $<
#	$(POSTCOMPILE)

%.obj: %.cpp $(DEPDIR)/%.d
	$(COMPILE.cc) $(OUTPUT_OPTION) $<
#	$(POSTCOMPILE)

$(DEPDIR)/%.d: %.cpp ;
$(DEPDIR)/gpuowl-wrap.d: gpuowl-wrap.cpp ;

$(DEPDIR): FORCE
	mkdir -p $(DEPDIR)

version.h: version.inc ;

version.inc: FORCE
	echo \"`git describe --tags --long --dirty --always`\" > version.new
	diff -q -N version.new version.inc >/dev/null || mv version.new version.inc
	echo Version `cat version.inc`

gpuowl-expanded.cl: gpuowl.cl tools/expand.py
	python3 ./tools/expand.py < gpuowl.cl > gpuowl-expanded.cl

gpuowl-wrap.cpp: gpuowl.cl
	python3 tools/expand.py < gpuowl.cl > gpuowl-wrap.cpp

install: $(EXE)
	install -m 555 $(EXE) ../

FORCE:

include $(wildcard $(patsubst %,$(DEPDIR)/%.Td,$(basename $(SRCS))))
