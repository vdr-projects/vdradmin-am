DESTDIR=
LIBDIR=/usr/share/vdradmin
ETCDIR=/etc/vdradmin
DOCDIR=/usr/share/doc/vdradmin
BINDIR=/usr/bin

distclean:
	rm -f vdradmind.conf vdradmind.at vdradmind.pid vdradmind.log

install:
	@if [ ! -d $(DESTDIR)$(BINDIR) ]; then \
		mkdir -p $(DESTDIR)$(BINDIR); \
	fi
	sed -e "s/my \$$SEARCH_FILES_IN_SYSTEM = 0; \# for distribution/my \$$SEARCH_FILES_IN_SYSTEM = 1;/" < vdradmind.pl > $(DESTDIR)$(BINDIR)/vdradmind.pl
	chmod a+x  $(DESTDIR)$(BINDIR)/vdradmind.pl
	@if [ ! -d $(DESTDIR)$(LIBDIR) ]; then \
		mkdir -p $(DESTDIR)$(LIBDIR); \
	fi
	cp -r template lib $(DESTDIR)$(LIBDIR)
	@if [ ! -d $(DESTDIR)$(ETCDIR) ]; then \
		mkdir -p $(DESTDIR)$(ETCDIR); \
	fi
	@if [ ! -d $(DESTDIR)$(DOCDIR) ]; then \
		mkdir -p $(DESTDIR)$(DOCDIR); \
	fi
	cp -r COPYING HISTORY INSTALL contrib $(DESTDIR)$(DOCDIR)	
