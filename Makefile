###############################################################################
# "THE BEER-WARE LICENSE" (Revision 42):
# <msmith@FreeBSD.ORG> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return
###############################################################################
#
# Makefile for building the baseflight firmware.
#
# Invoke this with 'make help' to see the list of supported targets.
#

###############################################################################
# Things that the user might override on the commandline
#

# The target to build, must be one of NAZE or <deleted>
TARGET		?= OPLINK

# Compile-time options
OPTIONS		?=

###############################################################################
# Things that need to be maintained as the source changes
#

VALID_TARGETS	 = OPLINK

# Working directories
ROOT			= $(dir $(lastword $(MAKEFILE_LIST)))
SRC_DIR			= $(ROOT)/src
CMSIS_DIR		= $(ROOT)/lib/CMSIS
STDPERIPH_DIR	= $(ROOT)/lib/STM32F10x_StdPeriph_Driver
USBFS_DIR		= $(ROOT)/lib/STM32_USB-FS-Device_Driver
OBJECT_DIR		= $(ROOT)/obj
BIN_DIR			= $(ROOT)/obj

# Source files common to all targets
COMMON_SRC	 = startup_stm32f10x_md_gcc.S \
				main.c \
				led.c \
				systick.c \
				$(CMSIS_SRC) \
				$(STDPERIPH_SRC)

.PRECIOUS: %.s

# Search path for baseflight sources
VPATH		:= $(SRC_DIR):$(SRC_DIR)/baseflight_startups

# Search path and source files for the CMSIS sources
VPATH		:= $(VPATH):$(CMSIS_DIR)/CM3/CoreSupport:$(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x
CMSIS_SRC	 = $(notdir $(wildcard $(CMSIS_DIR)/CM3/CoreSupport/*.c \
									   $(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x/*.c))

# Search path and source files for the ST stdperiph library
VPATH		:= $(VPATH):$(STDPERIPH_DIR)/src
STDPERIPH_SRC	 = $(notdir $(wildcard $(STDPERIPH_DIR)/src/*.c))

# Search path and source files for the ST stdperiph library
VPATH		:= $(VPATH):$(USBFS_DIR)/src
USBPERIPH_SRC	 = $(notdir $(wildcard $(USBFS_DIR)/src/*.c))

###############################################################################
# Things that might need changing to use different tools
#

# Tool names
CC		 = arm-none-eabi-gcc
OBJCOPY		 = arm-none-eabi-objcopy

#
# Tool options.
#
INCLUDE_DIRS	 = $(SRC_DIR) \
				   $(STDPERIPH_DIR)/inc \
				   $(USBFS_DIR)/inc \
				   $(CMSIS_DIR)/CM3/CoreSupport \
				   $(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x \

ARCH_FLAGS	 = -mthumb -mcpu=cortex-m3

OPTIMIZE	 = -Os
LTO_FLAGS	 = -flto $(OPTIMIZE)

CFLAGS		 = $(ARCH_FLAGS) \
				   $(LTO_FLAGS) \
				   $(addprefix -D,$(OPTIONS)) \
				   $(addprefix -I,$(INCLUDE_DIRS)) \
				   -Wall \
				   -Wdouble-promotion \
				   -ffunction-sections \
				   -fdata-sections \
				   -DSTM32F10X_MD \
				   -DUSE_STDPERIPH_DRIVER \
				   -D$(TARGET)

ASFLAGS		 = $(ARCH_FLAGS) \
				   -x assembler-with-cpp \
				   $(addprefix -I,$(INCLUDE_DIRS))

# XXX Map/crossref output?
LD_SCRIPT	 = $(ROOT)/stm32_flash.ld
LDFLAGS		 = -lm \
				   $(ARCH_FLAGS) \
				   $(LTO_FLAGS) \
				   -static \
				   -Wl,-gc-sections,-Map,$(TARGET_MAP) \
				   -T$(LD_SCRIPT)

###############################################################################
# No user-serviceable parts below
###############################################################################

#
# Things we will build
#
ifeq ($(filter $(TARGET),$(VALID_TARGETS)),)
$(error Target '$(TARGET)' is not valid, must be one of $(VALID_TARGETS))
endif

TARGET_HEX	 = $(BIN_DIR)/baseflight_$(TARGET).hex
TARGET_BIN	 = $(BIN_DIR)/baseflight_$(TARGET).bin
TARGET_ELF	 = $(BIN_DIR)/baseflight_$(TARGET).elf
TARGET_OBJS	 = $(addsuffix .o,$(addprefix $(OBJECT_DIR)/$(TARGET)/,$(basename $($(TARGET)_SRC))))
TARGET_MAP   = $(BIN_DIR)/baseflight_$(TARGET).map

# List of buildable ELF files and their object dependencies.
# It would be nice to compute these lists, but that seems to be just beyond make.

all: $(TARGET_ELF) $(TARGET_BIN) $(TARGET_HEX)

$(TARGET_HEX): $(TARGET_ELF)
		$(OBJCOPY) -O ihex $< $@

$(TARGET_BIN): $(TARGET_ELF)
		$(OBJCOPY) -O binary $< $@

$(TARGET_ELF):  $(TARGET_OBJS)
		$(CC) -o $@ $^ $(LDFLAGS)

# Compile
$(OBJECT_DIR)/$(TARGET)/%.o: %.c
		@mkdir -p $(dir $@)
		@echo %% $(notdir $<)
		@$(CC) -c -o $@ $(CFLAGS) $<

# Assemble
$(OBJECT_DIR)/$(TARGET)/%.o: %.s
		@mkdir -p $(dir $@)
		@echo %% $(notdir $<)
		@$(CC) -c -o $@ $(ASFLAGS) $<
$(OBJECT_DIR)/$(TARGET)/%.o): %.S
		@mkdir -p $(dir $@)
		@echo %% $(notdir $<)
		@$(CC) -c -o $@ $(ASFLAGS) $<

clean:
		rm -f $(TARGET_HEX) $(TARGET_BIN) $(TARGET_ELF) $(TARGET_OBJS) $(TARGET_MAP)

help:
		@echo ""
		@echo "Makefile for the OPLRS32 firmware"
		@echo ""
		@echo "Usage:"
		@echo "        make [TARGET=<target>] [OPTIONS=\"<options>\"]"
		@echo ""
		@echo "Valid TARGET values are: $(VALID_TARGETS)"
		@echo ""
