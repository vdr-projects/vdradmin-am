all: $(LANGS)

$(LANGS):
	msgfmt $@.po -o $@.mo

clean:
	-rm -f *.mo
	-rm -f build_stamp
