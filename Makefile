CXXFLAGS = -Wall -g -O3 -std=gnu++17 -I.

ifeq (yes,$(shell test -d /opt/rocm-4.0.0/opencl/lib && echo 'yes'))
CUDA_LIBS = -L/opt/rocm-4.0.0/opencl/lib -L/opt/rocm/opencl/lib -L/opt/rocm/opencl/lib/x86_64 -L/opt/amdgpu-pro/lib/x86_64-linux-gnu -lOpenCL
CUDA_INCL =
else
ifeq (yes,$(shell test -d /opt/rocm-3.3.0/opencl/lib/x86_64 && echo 'yes'))
CUDA_LIBS = -L/opt/rocm-3.3.0/opencl/lib/x86_64 -L/opt/rocm/opencl/lib/x86_64 -L/opt/rocm/opencl/lib/x86_64 -L/opt/amdgpu-pro/lib/x86_64-linux-gnu -lOpenCL
CUDA_INCL =
else
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
CUDA_LIBS = -L/opt/rocm-4.0.0/opencl/lib -L/opt/rocm-3.3.0/opencl/lib/x86_64 -L/opt/rocm/opencl/lib -L/opt/rocm/opencl/lib/x86_64 -L/opt/amdgpu-pro/lib/x86_64-linux-gnu
CUDA_INCL = -IdefaultCUDA_LIBS
endif
endif
endif
endif
endif

LIBPATH = $(CUDA_LIBS) -L.

LDFLAGS = -lstdc++fs $(LIBPATH) -lgmp -pthread -lquadmath $(LIBPATH)

LINK = $(CXX) $(CXXFLAGS)

SRCS=$(wildcard *.cpp)

# Change this to obj on MSWindows
O=o

OBJS = $(SRCS:%.cpp=%.$(O))
OWL_OBJS=$(filter-out D.$(O) sine_compare.$(O) qdcheb.$(O),$(OBJS))

DEPDIR := .d
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.Td
COMPILE.cc = $(CXX) $(DEPFLAGS) $(CXXFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c
POSTCOMPILE = @mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d && touch $@

all: .d version.inc gpuowl
	echo $@ > $@

gpuowl: $(OWL_OBJS)
	$(LINK) $^ -o $@ $(LDFLAGS)

gpuowl-win.exe: $(OWL_OBJS)
	$(LINK) -static $^ -o $@ $(LDFLAGS)
	strip $@

D:	D.$(O) Pm1Plan.$(O) log.$(O) common.$(O) timeutil.$(O)
	$(LINK) $^ -o $@ $(LDFLAGS)

clean:
	rm -f $(OBJS) gpuowl gpuowl-win.exe
	rm -rf $(DEPDIR)

%.o: %.cpp $(DEPDIR)/%.d gpuowl-wrap.cpp version.inc
	$(COMPILE.cc) $(OUTPUT_OPTION) $<
	$(POSTCOMPILE)

$(DEPDIR)/%.d: %.cpp

.d: FORCE
	mkdir -p $(DEPDIR)

version.inc: FORCE
	echo \"`git describe --tags --long --dirty --always`\" > version.new
	diff -q -N version.new version.inc >/dev/null || mv version.new version.inc
	echo Version `cat version.inc`

gpuowl-expanded.cl: gpuowl.cl
	./tools/expand.py < gpuowl.cl > gpuowl-expanded.cl

gpuowl-wrap.cpp: gpuowl-expanded.cl head.txt tail.txt
	cat head.txt gpuowl-expanded.cl tail.txt > gpuowl-wrap.cpp

install: gpuowl
	install -m 555 gpuowl ../

FORCE:

include $(wildcard $(patsubst %,$(DEPDIR)/%.d,$(basename $(SRCS))))
