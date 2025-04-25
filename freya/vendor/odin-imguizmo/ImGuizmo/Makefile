CXX ?= g++

# Flags
CXXFLAGS += -std=c++11 -O3 -fno-exceptions -fno-rtti -fno-threadsafe-statics
# CXXFLAGS += -DIMGUI_DEFINE_MATH_OPERATORS -DIMGUI_API='extern "C"'
CXXFLAGS += -DIMGUI_DEFINE_MATH_OPERATORS
LDFLAGS  += -static-libgcc -static-libstdc++

INCLUDES += -I../../odin-imgui/imgui
# INCLUDES += -I../../odin-imgui/imgui/backends

# Source files
CPPSRC = $(wildcard *.cpp)
OBJ = $(CPPSRC:.cpp=.o)
TARGET = libImGuizmo.a

# Build rules
all: $(TARGET)

$(TARGET): $(OBJ)
	$(AR) rcs $@ $^
	rm -f $(OBJ)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(OBJ) $(TARGET)

.PHONY: all clean
