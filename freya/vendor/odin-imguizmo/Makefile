CXX ?= g++
AR ?= ar

# Flags
CXXFLAGS += -std=c++11 -O2 -I.
CXXFLAGS += -DIMGUI_DEFINE_MATH_OPERATORS
LDFLAGS  = -static-libgcc -static-libstdc++

INCLUDES += -I../../odin-imgui/imgui

CPPSRC = $(wildcard *.cpp)
OBJ = $(CPPSRC:.cpp=.o)
TARGET = libImGuizmo.a

all: $(TARGET)
    rm -f $(OBJ)

%.o: %.cpp
	$(CXX)  $(LDFLAGS) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
    rm -f $(OBJ) $(TARGET)

.PHONY: all clean
