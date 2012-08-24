

all:
	clang -fobjc-arc -O2 -framework Foundation -framework ApplicationServices -o pdf2png main.m 
#	clang -g -arch i386 -framework Foundation -framework CoreGraphics -o pdf2png main.m 

clean:
	rm -f pdf2png main.o