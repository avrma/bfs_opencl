#Author: Anshuman Verma 
#Email : anshuman@vt.edu
#Date  : Oct 1st, 2016 
#Description : Makefile for BFS, based on Altera Provided Makefiles for sample programs 

# Compiler 
CC  := gcc
CXX := g++

# Lib Compile Option 
LIB_COMPILE_OPT := -g -c -fPIC -shared

DEFINES=
O=fpga.aocx
K=bfs_kernel
G=small.gr
S=20
SRC=src/host
DEV=src/device
LIB_DIR=src/lib
LIB_OPT=-L ./  -L ./$(LIB_DIR)
INCLUDE=-I . -I $(SRC) 
FPGA_DB=compile_db
AOCX_OUT=$(FPGA_DB)/$(K).aocx
KERNEL=$(DEV)/$(K).cl 

ifeq ($(VERBOSE),1)
ECHO := 
else
ECHO := @
endif

# Where is the Altera SDK for OpenCL software?
ifeq ($(wildcard $(ALTERAOCLSDKROOT)),)
$(error Set ALTERAOCLSDKROOT to the root directory of the Altera SDK for OpenCL software installation)
endif
ifeq ($(wildcard $(ALTERAOCLSDKROOT)/host/include/CL/opencl.h),)
$(error Set ALTERAOCLSDKROOT to the root directory of the Altera SDK for OpenCL software installation.)
endif

# OpenCL compile and link flags.
AOCL_COMPILE_CONFIG := $(shell aocl compile-config )
AOCL_LINK_CONFIG := $(shell aocl link-config )

# Compilation flags
ifeq ($(DEBUG),1)
CXXFLAGS += -g
else
CXXFLAGS += -O2
endif

# Compiler
CXX := g++

# Target
TARGET := bfs
TARGET_DIR := bin

# Directories
INC_DIRS := src/host src/inc
LIB_DIRS := src/lib

# Files
INCS := $(wildcard )
SRCS := $(wildcard src/host/*.cpp src/host/*.c)
LIBS := 
DEVICE := $(wildcard src/device/*.cl)
#
## Make it all!
all : $(TARGET_DIR)/$(TARGET)
#
## Host executable target.
#$(TARGET_DIR)/$(TARGET) : Makefile $(SRCS) $(INCS) $(TARGET_DIR)
#	$(ECHO)$(CXX) $(CPPFLAGS) $(CXXFLAGS) -fPIC $(foreach D,$(INC_DIRS),-I$D) \
#			$(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) \
#			$(foreach D,$(LIB_DIRS),-L$D) \
#			$(foreach L,$(LIBS),-l$L) \
#			-o $(TARGET_DIR)/$(TARGET)
#
$(TARGET_DIR) :
	$(ECHO)mkdir $(TARGET_DIR)
	$(ECHO)mkdir $(LIB_DIR)
	


#all : $(BUILD)/bfs 

run: 
	$(TARGET_DIR)/$(TARGET) -t 3 -d 0 -- \
		./test/small.txt \
		$(FPGA_DB)/$(K) \
		./test/$(G) $(S) \
		$(S)

emulate: $(TARGET_DIR)/$(TARGET) $(AOCX_OUT) $(DEVICE)
	env CL_CONTEXT_EMULATOR_DEVICE_ALTERA=s5phq_d8 \
		$(TARGET_DIR)/$(TARGET) -t 3 -d 0 -- \
		./test/small.txt \
		$(FPGA_DB)/$(K) \
		./test/$(G) \
		$(S)

$(TARGET_DIR)/$(TARGET): $(SRC)/bfs.cpp $(LIB_DIR)/libcommon.so $(LIB_DIR)/libopts.so $(LIB_DIR)/librdtsc.so
	$(CXX) $(SRC)/bfs.cpp -std=c++0x \
		$(INCLUDE) \
		$(DEFINES) \
		$(LIB_OPT) \
		$(AOCL_LINK_CONFIG) \
		-lcommon \
		-lopts \
		-lrdtsc \
		-o $(TARGET_DIR)/$(TARGET)

$(LIB_DIR)/libcommon.so: $(SRC)/common_args.c $(SRC)/common_args.h $(LIB_DIR)/libopts.so $(LIB_DIR)/librdtsc.so
	$(CXX) $(SRC)/common_args.c \
		$(LIB_COMPILE_OPT) \
		$(DEFINES) \
		$(AOCL_COMPILE_CONFIG) \
		$(LIB_OPT) \
		$(INCLUDE) \
		-lopts \
		-lrdtsc \
		-o $(LIB_DIR)/libcommon.so

$(LIB_DIR)/libopts.so: $(SRC)/opts.c $(SRC)/opts.h
	$(CC) $(SRC)/opts.c \
		$(LIB_COMPILE_OPT) \
		$(DEFINES) \
		$(AOCL_COMPILE_CONFIG) \
		$(LIB_OPT) \
		-o $(LIB_DIR)/libopts.so

$(LIB_DIR)/librdtsc.so: $(SRC)/rdtsc.c $(SRC)/rdtsc.h
	$(CC) $(SRC)/rdtsc.c \
		$(LIB_COMPILE_OPT) \
		$(DEFINES) \
		$(AOCL_COMPILE_CONFIG) \
		$(LIB_OPT) \
		-o $(LIB_DIR)/librdtsc.so

clean:
	$(ECHO)rm -f $(TARGET_DIR)/$(TARGET)
	$(ECHO)rm -f $(LIB_DIR)/*.so

$(AOCX_OUT): $(KERNEL) $(DEVICE)
	aoc -g -march=emulator $(KERNEL) -o $(AOCX_OUT) $(DEFINES)

full_compile:
	if [ $(O) = 'fpga.aocx' ]; then \
		echo "error, PASS THE OUTOUT FILE NAME with .aocx extension"; \
		echo "make -f Makefile_altera O=<filename>"; \
	else \
		aoc -v -g --profile  $(KERNEL)  -o $(FPGA_DB)/$(O) $(DEFINES); \
	fi \


.PHONY : all clean emulate full_compile run
