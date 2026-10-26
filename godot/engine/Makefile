# Builds the shogi GDExtension (Fairy-Stockfish + godot-cpp) into ../bin/.
#   make PLATFORM=linux   ARCH=x86_64
#   make PLATFORM=android ARCH=arm64  ANDROID_NDK_ROOT=/path/to/ndk   (also ARCH=x86_64)
# build.sh wraps this and fetches the dependencies; see README.md.

PLATFORM ?= linux
ARCH ?= x86_64
ANDROID_API ?= 24
JOBS ?= 4

GODOT_CPP := thirdparty/godot-cpp
FS := thirdparty/Fairy-Stockfish/src
BUILD := build/$(PLATFORM)-$(ARCH)
LIB := ../bin/libshogi_engine.$(PLATFORM).template_release.$(ARCH).so

ifeq ($(PLATFORM),android)
  TOOLCHAIN := $(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin
  TRIPLE := $(if $(filter arm64,$(ARCH)),aarch64,x86_64)-linux-android$(ANDROID_API)
  CXX := $(TOOLCHAIN)/clang++ --target=$(TRIPLE)
  AR := $(TOOLCHAIN)/llvm-ar
  PLATFORM_DEFINES := -DANDROID_ENABLED -DUNIX_ENABLED
  # Android 15+ devices may use 16 KB pages: align the ELF segments for them.
  PLATFORM_LDFLAGS := -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 -static-libstdc++
else
  CXX ?= g++
  AR ?= ar
  PLATFORM_DEFINES := -DLINUX_ENABLED -DUNIX_ENABLED
  PLATFORM_LDFLAGS := -static-libstdc++ -static-libgcc
endif

ifeq ($(ARCH),x86_64)
  # x86_64 Android guarantees SSE4.2 + POPCNT; desktop CPUs since ~2009 too.
  ARCH_FLAGS := -msse4.2 -mpopcnt
else
  ARCH_FLAGS :=
endif

COMMON := -std=c++17 -fPIC -O3 -fno-exceptions -fvisibility=hidden -ffunction-sections -fdata-sections \
  -DGDEXTENSION -DTHREADS_ENABLED -DNDEBUG $(PLATFORM_DEFINES) $(ARCH_FLAGS)
GODOT_INCLUDES := -I$(GODOT_CPP)/include -I$(GODOT_CPP)/gen/include -I$(GODOT_CPP)/gdextension
# Shogi is 9x9, so it needs Fairy-Stockfish's large-board (128-bit) bitboards; NNUE stays off
# (the PWA also plays with the classical evaluation).
FS_DEFINES := -DLARGEBOARDS -DPRECOMPUTED_MAGICS -DNNUE_EMBEDDING_OFF -DIS_64BIT -DUSE_PTHREADS -DUSE_POPCNT -fno-strict-aliasing

GODOT_SRCS := $(wildcard $(GODOT_CPP)/src/*.cpp $(GODOT_CPP)/src/*/*.cpp $(GODOT_CPP)/gen/src/*/*.cpp)
FS_SRCS := $(filter-out %/main.cpp %/ffishjs.cpp %/pyffish.cpp,$(wildcard $(FS)/*.cpp)) \
  $(wildcard $(FS)/syzygy/*.cpp $(FS)/nnue/*.cpp $(FS)/nnue/features/*.cpp)
OUR_SRCS := $(wildcard src/*.cpp)

GODOT_OBJS := $(patsubst %.cpp,$(BUILD)/%.o,$(GODOT_SRCS))
FS_OBJS := $(patsubst %.cpp,$(BUILD)/%.o,$(FS_SRCS))
OUR_OBJS := $(patsubst %.cpp,$(BUILD)/%.o,$(OUR_SRCS))
GODOT_LIB := $(BUILD)/libgodot-cpp.a

all: $(LIB)

$(LIB): $(OUR_OBJS) $(FS_OBJS) $(GODOT_LIB)
	@mkdir -p $(dir $@)
	$(CXX) -shared -o $@ $(OUR_OBJS) $(FS_OBJS) $(GODOT_LIB) -Wl,--gc-sections -s -pthread $(PLATFORM_LDFLAGS)

$(GODOT_LIB): $(GODOT_OBJS)
	$(AR) rcs $@ $^

$(BUILD)/$(GODOT_CPP)/%.o: $(GODOT_CPP)/%.cpp
	@mkdir -p $(dir $@)
	@$(CXX) $(COMMON) $(GODOT_INCLUDES) -w -c $< -o $@

$(BUILD)/$(FS)/%.o: $(FS)/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(COMMON) $(FS_DEFINES) -w -c $< -o $@

$(BUILD)/src/%.o: src/%.cpp src/*.h
	@mkdir -p $(dir $@)
	$(CXX) $(COMMON) $(FS_DEFINES) $(GODOT_INCLUDES) -I$(FS) -Wall -c $< -o $@

clean:
	rm -rf build

.PHONY: all clean
