CC = gcc
CFLAGS = -O2 -fPIC -Wall
LUADIR = ../../../../3rd/lua 
TARGET = protobuf.so
SHARED = -shared

.PHONY : all clean

all : $(TARGET)

$(TARGET) : pbc-lua53.c
	$(CC) $(CFLAGS) $(SHARED) -o $@ -I../.. -I$(LUADIR) -L../../build $^ -lpbc

clean :
	rm -f $(TARGET)
