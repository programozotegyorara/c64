PRG     = scroll.prg
SRC     = scroll.s
OBJ     = scroll.o
TARGET  = c64

CA65    = ca65
LD65    = ld65
VICE    = x64sc

all: $(PRG)

$(OBJ): $(SRC)
	$(CA65) $(SRC) -o $(OBJ)

$(PRG): $(OBJ) c64-asm.cfg
	$(LD65) $(OBJ) -o $(PRG) -C c64-asm.cfg

run: $(PRG)
	$(VICE) $(PRG)

clean:
	rm -f $(OBJ) $(PRG)

.PHONY: all run clean
