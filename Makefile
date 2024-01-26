BIN=build
CXXFLAGS = -Wall -g -O3 -std=gnu++17
CPPFLAGS = -I$(BIN) -I.

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
CUDA_LIBS = -fPIC -L/usr/local/cuda-11/lib64 -lcudart -lOpenCL
CUDA_INCL = -I/usr/local/cuda-11/include
endif
ifeq (yes,$(shell test -d /usr/local/cuda-10 && echo 'yes'))
CUDA_LIBS = -fPIC -L/usr/local/cuda-10/lib64 -lcudart -lOpenCL
CUDA_INCL = -I/usr/local/cuda-10/include
endif

ifeq (,$(CUDA_LIBS))
# default
CUDA_LIBS = -L/opt/rocm-5.1.1/opencl/lib -L/opt/rocm-4.0.0/opencl/lib -L/opt/rocm-3.3.0/opencl/lib/x86_64 -L/opt/rocm/opencl/lib -L/opt/rocm/opencl/lib/x86_64 -L/opt/amdgpu-pro/lib/x86_64-linux-gnu -lOpenCL
endif
ifeq (,$(CUDA_INCL))
CUDA_INCL = -IdefaultCUDA_LIBS
endif

LIBPATH = $(CUDA_LIBS) -L.

LDFLAGS = -lstdc++fs $(LIBPATH) -lgmp -pthread

LINK = $(CXX) $(CXXFLAGS)

SRCS1=$(wildcard *.cpp)
OBJS = $(SRCS1:%.cpp=$(BIN)/%.$(O))
OWL_OBJS=$(filter-out D.$(O) sine_compare.$(O) qdcheb.$(O),$(OBJS))

DEPDIR := $(BIN)/.d
$(shell mkdir -p $(DEPDIR) >/dev/null)

DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.Td
COMPILE.cc = $(CXX) $(DEPFLAGS) $(CXXFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c
POSTCOMPILE = @mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d && touch $@

all: .d version.inc gpuowl-wrap.cpp $(EXE)
	echo $@ > $@

gpuowl: $(OWL_OBJS) gpuowl-wrap.$(O)
	$(LINK) $^ -o $@ $(LDFLAGS)

#!!wedgingt gpuowl-cygwin.exe: $(OWL_OBJS) gpuowl-wrap.$(O)
#!!wedgingt	$(LINK) -static $^ -o $@ $(LDFLAGS)
$(BIN)/gpuowl: ${OBJS}
	${LINK}

gpuowl-win.exe: $(OWL_OBJS) gpuowl-wrap.$(O)
	$(LINK) -static $^ -o $@ $(LDFLAGS)
	strip $@

D:	D.$(O) Pm1Plan.$(O) log.$(O) common.$(O) timeutil.$(O)
	$(LINK) $^ -o $@ $(LDFLAGS)

clean:
	rm -f *.$(O) gpuowl gpuowl-win.exe gpuowl-wrap.cpp
	rm -f all gpuowl-expanded.cl gpuowl-cygwin.exe D
	rm -f version.inc install FORCE clean
	rm -rf $(BIN) $(DEPDIR)

$(BIN)/gpuowl-wrap.o : $(BIN)/gpuowl-wrap.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $(OUTPUT_OPTION) $<

$(BIN)/%.o: src/%.cpp $(DEPDIR)/%.d $(BIN)/version.inc
	$(COMPILE.cc) $(OUTPUT_OPTION) $<
	$(POSTCOMPILE)

$(BIN)/%.obj: src/%.cpp $(DEPDIR)/%.d $(BIN)/version.inc
	$(COMPILE.cc) $(OUTPUT_OPTION) $<
	$(POSTCOMPILE)

$(DEPDIR)/%.d: %.cpp ;
.PRECIOUS: $(DEPDIR)/%.d

$(DEPDIR):
	mkdir -p $(DEPDIR)

$(BIN)/version.h: $(BIN)/version.inc
	touch $@

$(BIN)/version.inc: FORCE
	echo \"`git describe --tags --long --dirty --always`\" > $(BIN)/version.new
	diff -q -N $(BIN)/version.new $(BIN)/version.inc >/dev/null || mv $(BIN)/version.new $(BIN)/version.inc
	echo Version: `cat $(BIN)/version.inc`

gpuowl-expanded.cl: gpuowl.cl tools/expand.py
	python3 ./tools/expand.py < gpuowl.cl > gpuowl-expanded.cl

$(BIN)/gpuowl-wrap.cpp: src/gpuowl.cl
	python3 tools/expand.py src/gpuowl.cl $(BIN)/gpuowl-wrap.cpp

install: $(EXE)
	install -m 555 $(EXE) ../

FORCE:

include $(wildcard $(patsubst %,$(DEPDIR)/%.d,$(basename $(SRCS1))))

# include $(wildcard $(patsubst %,$(DEPDIR)/%.d,$(basename D.cpp)))
