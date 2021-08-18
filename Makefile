
SOURCES_ASM := start.S main.S mailboxes.S lfb.S
SOURCES_C   :=

OBJS	:= $(patsubst %.S,%.o,$(SOURCES_ASM))
OBJS	+= $(patsubst %.c,%.o,$(SOURCES_C))

INCLUDES	:= -I.
ASFLAGS		:=
CFLAGS		:= $(INCLUDES)

all: clean kernel7.img

kernel7.img: bare.elf
	/usr/local/cross-compiler/bin/aarch64-elf-objcopy bare.elf -O binary kernel7.img

bare.elf: $(OBJS) link.ld
	/usr/local/cross-compiler/bin/aarch64-elf-ld $(OBJS) -Tlink.ld -o $@

#There's no C files though...
%.o: %.c
	aarch64-elf-gcc $(CFLAGS) -c $< -o $@

%.o: %.S
	/usr/local/cross-compiler/bin/aarch64-elf-as $(ASFLAGS) -c $< -o $@

clean:
	$(RM)  -f $(OBJS) kernel7.elf kernel7.img

dist-clean: clean
	$(RM) -f *~
