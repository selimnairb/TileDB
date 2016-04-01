##########
# Macros #
##########

OS := $(shell uname)

# Configuration flags
CONFIG_FLAGS =

ifdef TRAVIS
  CONFIG_FLAGS += --coverage
endif

# Use of mmap function for reading
USE_MMAP =

ifeq ($(USE_MMAP),)
  USE_MMAP = 1
endif

ifeq ($(USE_MMAP),1)
  CONFIG_FLAGS += -D_TILEDB_USE_MMAP
endif

# Large file support
LFS_CFLAGS = -D_FILE_OFFSET_BITS=64

# Parallel sort
GNU_PARALLEL =

ifeq ($(GNU_PARALLEL),)
  GNU_PARALLEL = 1
endif

ifeq ($(GNU_PARALLEL),1)
  CFLAGS = -fopenmp -DGNU_PARALLEL
else
  CFLAGS =
endif

# --- Debug/Release/Verbose mode handler --- #
BUILD =
VERBOSE =

ifeq ($(BUILD),)
  BUILD = release
endif
 
ifeq ($(BUILD),release)
  CFLAGS += -DNDEBUG -O3 
endif

ifeq ($(BUILD),debug)
  CFLAGS += -DDEBUG -gdwarf-3 -g3
endif

ifeq ($(VERBOSE),)
  VERBOSE = 2
endif

ifeq ($(VERBOSE),0)
  CFLAGS += -DNVERBOSE
endif

ifneq ($(VERBOSE),0)
  CFLAGS += -DVERBOSE=$(VERBOSE)
endif

# --- Set library path to Google Test shared objects --- #
LDFLAGS += -L$(PWD)/3rdparty/gtest/lib
LDFLAGS += -Wl,-R$(PWD)/3rdparty/gtest/lib `$$ORIGIN`

# --- Compilers --- #

# C++ compiler
# CXX = g++ 

# MPI compiler for C++
MPIPATH = #/opt/mpich/dev/intel/default/bin/
MPICXX = mpicxx
CXX = $(MPIPATH)$(MPICXX) -lstdc++ -std=c++11 -fPIC -fvisibility=hidden \
      $(LFS_CFLAGS) $(CFLAGS) $(CONFIG_FLAGS) 

# --- Directories --- #
# Directories for the core code of TileDB
CORE_INCLUDE_DIR = core/include
CORE_INCLUDE_SUBDIRS = $(wildcard core/include/*)
CORE_SRC_DIR = core/src
CORE_SRC_SUBDIRS = $(wildcard core/src/*)
CORE_OBJ_DEB_DIR = core/obj/debug
CORE_BIN_DEB_DIR = core/bin/debug
ifeq ($(BUILD),debug)
  CORE_OBJ_DIR = $(CORE_OBJ_DEB_DIR)
  CORE_BIN_DIR = $(CORE_BIN_DEB_DIR)
endif
CORE_OBJ_REL_DIR = core/obj/release
CORE_BIN_REL_DIR = core/bin/release
ifeq ($(BUILD),release)
  CORE_OBJ_DIR = $(CORE_OBJ_REL_DIR)
  CORE_BIN_DIR = $(CORE_BIN_REL_DIR)
endif
CORE_LIB_DEB_DIR = core/lib/debug
ifeq ($(BUILD),debug)
  CORE_LIB_DIR = $(CORE_LIB_DEB_DIR)
endif
CORE_LIB_REL_DIR = core/lib/release
ifeq ($(BUILD),release)
  CORE_LIB_DIR = $(CORE_LIB_REL_DIR)
endif

# Directories for the examples
EXAMPLES_INCLUDE_DIR = examples/include
EXAMPLES_SRC_DIR = examples/src
EXAMPLES_OBJ_DEB_DIR = examples/obj/debug
EXAMPLES_BIN_DEB_DIR = examples/bin/debug
ifeq ($(BUILD),debug)
  EXAMPLES_OBJ_DIR = $(EXAMPLES_OBJ_DEB_DIR)
  EXAMPLES_BIN_DIR = $(EXAMPLES_BIN_DEB_DIR)
endif
EXAMPLES_OBJ_REL_DIR = examples/obj/release
EXAMPLES_BIN_REL_DIR = examples/bin/release
ifeq ($(BUILD),release)
  EXAMPLES_OBJ_DIR = $(EXAMPLES_OBJ_REL_DIR)
  EXAMPLES_BIN_DIR = $(EXAMPLES_BIN_REL_DIR)
endif

# Directories for TileDB tests
TEST_SRC_SUBDIRS = $(wildcard test/src/*)
TEST_SRC_DIR = test/src
TEST_OBJ_DIR = test/obj
TEST_BIN_DIR = test/bin

# Directory for Doxygen documentation
DOXYGEN_DIR = doxygen
DOXYGEN_MAINPAGE = $(DOXYGEN_DIR)/mainpage.dox

# Directories for the MPI files - not necessary if mpicxx used.
MPI_INCLUDE_DIR := .
MPI_LIB_DIR := .

# Directories for the OpenMP files
OPENMP_INCLUDE_DIR = .
OPENMP_LIB_DIR = .

# --- Paths --- #
CORE_INCLUDE_PATHS = $(addprefix -I, $(CORE_INCLUDE_SUBDIRS))
TEST_INCLUDE_PATHS = $(addprefix -I, $(CORE_INCLUDE_SUBDIRS))

EXAMPLES_INCLUDE_PATHS = -I$(EXAMPLES_INCLUDE_DIR)
LA_INCLUDE_PATHS = -I$(LA_INCLUDE_DIR)
MPI_INCLUDE_PATHS = -I$(MPI_INCLUDE_DIR)
MPI_LIB_PATHS = -L$(MPI_LIB_DIR)
OPENMP_INCLUDE_PATHS = -L$(OPENMP_INCLUDE_DIR)
OPENMP_LIB_PATHS = -L$(OPENMP_LIB_DIR)

# --- Libs --- #
MPI_LIB = -lmpi
OPENMP_LIB = -fopenmp 
ZLIB = -lz
OPENSSLLIB = -lcrypto

# --- File Extensions --- #
ifeq ($(OS), Darwin)
  SHLIB_EXT = dylib
else
  SHLIB_EXT = so
endif

# --- Files --- #

# Files of the TileDB core
CORE_INCLUDE := $(foreach D,$(CORE_INCLUDE_SUBDIRS),$D/*.h) 
CORE_SRC := $(wildcard $(foreach D,$(CORE_SRC_SUBDIRS),$D/*.cc))
CORE_OBJ := $(patsubst $(CORE_SRC_DIR)/%.cc, $(CORE_OBJ_DIR)/%.o, $(CORE_SRC))

# Files of the examples
EXAMPLES_INCLUDE := $(wildcard $(EXAMPLES_INCLUDE_DIR)/*.h)
EXAMPLES_SRC := $(wildcard $(EXAMPLES_SRC_DIR)/*.cc)
EXAMPLES_OBJ := $(patsubst $(EXAMPLES_SRC_DIR)/%.cc,\
                             $(EXAMPLES_OBJ_DIR)/%.o, $(EXAMPLES_SRC))
EXAMPLES_BIN := $(patsubst $(EXAMPLES_SRC_DIR)/%.cc,\
                             $(EXAMPLES_BIN_DIR)/%, $(EXAMPLES_SRC)) 

# Files of the TileDB tests
TEST_SRC := $(wildcard $(foreach D,$(TEST_SRC_SUBDIRS),$D/*.cc))
TEST_OBJ := $(patsubst $(TEST_SRC_DIR)/%.cc, $(TEST_OBJ_DIR)/%.o, $(TEST_SRC))

###################
# General Targets #
###################

.PHONY: core examples test doc clean_core \
        clean_test clean_tiledb_cmd clean_examples \
        clean

all: core libtiledb 

core: $(CORE_OBJ) 

libtiledb: core $(CORE_LIB_DIR)/libtiledb.$(SHLIB_EXT) $(CORE_LIB_DIR)/libtiledb.a

examples: core $(EXAMPLES_OBJ) $(EXAMPLES_BIN)

doc: doxyfile.inc 

test: libtiledb $(TEST_BIN_DIR)/tiledb_test
	@echo "Running TileDB tests"
	@$(TEST_BIN_DIR)/tiledb_test

clean: clean_core clean_libtiledb \
       clean_test clean_doc clean_examples 

########
# Core #
########

# --- Compilation and dependency genration --- #

-include $(CORE_OBJ:%.o=%.d)

$(CORE_OBJ_DIR)/%.o: $(CORE_SRC_DIR)/%.cc
	@mkdir -p $(dir $@) 
	@echo "Compiling $<"
	@$(CXX) $(CORE_INCLUDE_PATHS) $(OPENMP_INCLUDE_PATHS) \
                $(MPI_INCLUDE_PATHS) -c $< $(ZLIB) $(OPENSSLLIB) -o $@ 
	@$(CXX) -MM $(CORE_INCLUDE_PATHS) $< > $(@:.o=.d)
	@mv -f $(@:.o=.d) $(@:.o=.d.tmp)
	@sed 's|.*:|$@:|' < $(@:.o=.d.tmp) > $(@:.o=.d)
	@rm -f $(@:.o=.d.tmp)

# --- Cleaning --- #

clean_core: 
	@echo 'Cleaning core'
	@rm -rf $(CORE_OBJ_DEB_DIR)/* $(CORE_OBJ_REL_DIR)/* \
                $(CORE_BIN_DEB_DIR)/* $(CORE_BIN_REL_DIR)/*

#############
# libtiledb #
#############

-include $(CORE_OBJ:%.o=%.d)

# --- Linking --- #

ifeq ($(0S), Darwin)
  SHLIB_FLAGS = -dynamiclib
else
  SHLIB_FLAGS = -shared
endif

ifeq ($(SHLIB_EXT), so)
  SONAME = -Wl,-soname=libtiledb.so
else
  SONAME =
endif

$(CORE_LIB_DIR)/libtiledb.$(SHLIB_EXT): $(CORE_OBJ)
	@mkdir -p $(CORE_LIB_DIR)
	@echo "Creating dynamic library libtiledb.$(SHLIB_EXT)"
	@$(CXX) $(SHLIB_FLAGS) $(SONAME) -o $@ $^ $(ZLIB) $(OPENSSLLIB)

$(CORE_LIB_DIR)/libtiledb.a: $(CORE_OBJ)
	@mkdir -p $(CORE_LIB_DIR)
	@echo "Creating static library libtiledb.a"
	@ar rcs $(CORE_LIB_DIR)/libtiledb.a $^

# --- Cleaning --- #

clean_libtiledb:
	@echo "Cleaning libtiledb.$(SHLIB_EXT)"
	@rm -rf $(CORE_LIB_DEB_DIR)/* $(CORE_LIB_REL_DIR)/*

##############
#  Examples  #
##############

# --- Compilation and dependency genration --- #

-include $(EXAMPLES_OBJ:.o=.d)

$(EXAMPLES_OBJ_DIR)/%.o: $(EXAMPLES_SRC_DIR)/%.cc
	@mkdir -p $(EXAMPLES_OBJ_DIR)
	@echo "Compiling $<"
	@$(CXX) $(EXAMPLES_INCLUDE_PATHS) $(CORE_INCLUDE_PATHS) -c $< \
         $(ZLIB) $(OPENSSLLIB) -o $@
	@$(CXX) -MM $(EXAMPLES_INCLUDE_PATHS) \
                    $(CORE_INCLUDE_PATHS) $< > $(@:.o=.d)
	@mv -f $(@:.o=.d) $(@:.o=.d.tmp)
	@sed 's|.*:|$@:|' < $(@:.o=.d.tmp) > $(@:.o=.d)
	@rm -f $(@:.o=.d.tmp)

# --- Linking --- #

$(EXAMPLES_BIN_DIR)/%: $(EXAMPLES_OBJ_DIR)/%.o $(CORE_OBJ)
	@mkdir -p $(EXAMPLES_BIN_DIR)
	@echo "Creating $@"
	@$(CXX) $(OPENMP_LIB_PATHS) $(OPENMP_LIB) $(MPI_LIB_PATHS) $(MPI_LIB) \
                -o $@ $^ $(ZLIB) $(OPENSSLLIB)

# --- Cleaning --- #

clean_examples:
	@echo 'Cleaning examples'
	@rm -f $(EXAMPLES_OBJ_DEB_DIR)/* $(EXAMPLES_OBJ_REL_DIR)/* \
               $(EXAMPLES_BIN_DEB_DIR)/* $(EXAMPLES_BIN_REL_DIR)/*

################
# TileDB Tests #
################

# --- Compilation and dependency genration --- #

-include $(TEST_OBJ:.o=.d)

$(TEST_OBJ_DIR)/%.o: $(TEST_SRC_DIR)/%.cc
	@mkdir -p $(dir $@) 
	@echo "Compiling $<"
	@$(CXX) $(TEST_INCLUDE_PATHS) -c $< -o $@
	@$(CXX) -MM $(TEST_INCLUDE_PATHS) \
                    $(CORE_INCLUDE_PATHS) $< > $(@:.o=.d)
	@mv -f $(@:.o=.d) $(@:.o=.d.tmp)
	@sed 's|.*:|$@:|' < $(@:.o=.d.tmp) > $(@:.o=.d)
	@rm -f $(@:.o=.d.tmp)

# --- Linking --- #

$(TEST_BIN_DIR)/tiledb_test: $(TEST_OBJ) $(CORE_OBJ)
	@mkdir -p $(TEST_BIN_DIR)
	@echo "Creating test_cmd"
	@$(CXX) $(LDFLAGS) $(OPENMP_LIB_PATHS) $(OPENMP_LIB) \
			$(MPI_LIB_PATHS) $(MPI_LIB) \
      -o $@ $^ $(ZLIB) $(OPENSSLLIB) -lgtest -lgtest_main

# --- Cleaning --- #

clean_test:
	@echo "Cleaning test"
	@rm -rf $(TEST_OBJ_DIR) $(TEST_BIN_DIR)
	

################################
# Documentation (with Doxygen) #
################################

doxyfile.inc: $(CORE_INCLUDE) $(TILEDB_CMD_INCLUDE) $(LA_INCLUDE) \
              $(DOXYGEN_MAINPAGE)
	@echo 'Creating Doxygen documentation'
	@echo INPUT = $(DOXYGEN_DIR)/mainpage.dox $(CORE_INCLUDE) \
                      $(TILEDB_CMD_INCLUDE) $(LA_INCLUDE) > doxyfile.inc
	@echo FILE_PATTERNS = *.h >> doxyfile.inc
	@doxygen Doxyfile.mk > Doxyfile.log 2>&1

# --- Cleaning --- #

clean_doc:
	@echo "Cleaning documentation"
	@rm -f doxyfile.inc

