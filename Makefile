#
default: aemet

#
aemet : aemet.l
	lex $^
	gcc lex.yy.c -o $@ -lfl
	rm lex.yy.c

#
clean:
	rm aemet

