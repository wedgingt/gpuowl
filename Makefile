CXXFLAGS = -Wall -O2 -std=c++17

ifeq (yes,$(shell test -d /opt/rocm/opencl/lib/x86_64 && echo 'yes'))
CUDA_LIBS = -L/opt/rocm-3.3.0/opencl/lib/x86_64 -L/opt/rocm-3.1.0/opencl/lib/x86_64 -L/opt/rocm/opencl/lib/x86_64 -L/opt/amdgpu-pro/lib/x86_64-linux-gnu -lOpenCL
CUDA_INCL =
else
ifeq (yes,$(shell test -d /usr/local/cuda-11 && echo 'yes'))
CUDA_LIBS = -fPIC -L/usr/local/cuda-11/lib64 -lcudart -lOpenCL
CUDA_INCL = -I/usr/local/cuda-11/include
else
ifeq (yes,$(shell test -d /usr/local/cuda-10 && echo 'yes'))
CUDA_LIBS = -fPIC -L/usr/local/cuda-10/lib64 -lcudart -lOpenCL
CUDA_INCL = -I/usr/local/cuda-10/include
else
error: FORCE
	@echo Add location of CUDA libraries and include files to Makefile
	exit 1
endif
endif
endif

LIBPATH = $(CUDA_LIBS) -L.

LDFLAGS = -lstdc++fs $(LIBPATH) -lgmp -pthread

LINK = $(CXX) -o $@ $(OBJS) $(LDFLAGS)

SRCS = Pm1Plan.cpp GmpUtil.cpp Worktodo.cpp common.cpp main.cpp Gpu.cpp clwrap.cpp Task.cpp checkpoint.cpp timeutil.cpp Args.cpp state.cpp Signal.cpp FFTConfig.cpp AllocTrac.cpp gpuowl-wrap.cpp sha3.cpp
OBJS = $(SRCS:%.cpp=%.o)
DEPDIR := .d
$(shell mkdir -p $(DEPDIR) >/dev/null)
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.Td
COMPILE.cc = $(CXX) $(DEPFLAGS) $(CXXFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c
POSTCOMPILE = @mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d && touch $@


gpuowl: $(OBJS)
	$(LINK)

gpuowl-win.exe: $(OBJS)
	$(LINK) -static
	strip $@

clean:
	rm -f $(OBJS) gpuowl gpuowl-win.exe

%.o : %.cpp
%.o : %.cpp $(DEPDIR)/%.d gpuowl-wrap.cpp version.inc
	$(COMPILE.cc) $(OUTPUT_OPTION) $<
	$(POSTCOMPILE)

$(DEPDIR)/%.d: ;
.PRECIOUS: $(DEPDIR)/%.d

version.inc: FORCE
	echo \"`git describe --long --dirty --always`\" > version.new
	diff -q -N version.new version.inc >/dev/null || mv version.new version.inc
	echo Version: `cat version.inc`

gpuowl-expanded.cl: gpuowl.cl
	./tools/expand.py < gpuowl.cl > gpuowl-expanded.cl

gpuowl-wrap.cpp: gpuowl-expanded.cl head.txt tail.txt
	cat head.txt gpuowl-expanded.cl tail.txt > gpuowl-wrap.cpp

FORCE:

include $(wildcard $(patsubst %,$(DEPDIR)/%.d,$(basename $(SRCS))))
