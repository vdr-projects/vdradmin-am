DESTDIR=
LIBDIR=/usr/share/vdradmin
ETCDIR=/etc/vdradmin
DOCDIR=/usr/share/doc/vdradmin
BINDIR=/usr/bin
LOCDIR=/usr/share/locale/
MANDIR=/usr/share/man/man1/

LANGS=de es fr fi

po/build_stamp:
	$(MAKE) -C po LANGS="$(LANGS)"
	for lang in $(LANGS); do \
	    [ ! -d locale/$$lang/LC_MESSAGES/ ] && mkdir -p locale/$$lang/LC_MESSAGES/; \
	    install -m 644 po/$$lang.mo locale/$$lang/LC_MESSAGES/vdradmin.mo; \
	done

all: po/build_stamp
	touch build_stamp

clean:
	$(MAKE) -C po clean
	-rm -f build_stamp

distclean: clean
	rm -f vdradmind.conf vdradmind.at vdradmind.bl vdradmind.done vdradmind.pid vdradmind.log

install:
	@if [ ! -d $(DESTDIR)$(BINDIR) ]; then \
		mkdir -p $(DESTDIR)$(BINDIR); \
	fi
	sed -e "s/^my \$$SEARCH_FILES_IN_SYSTEM = 0;/my \$$SEARCH_FILES_IN_SYSTEM = 1;/" < vdradmind.pl > $(DESTDIR)$(BINDIR)/vdradmind.pl
	chmod a+x  $(DESTDIR)$(BINDIR)/vdradmind.pl
	@if [ ! -d $(DESTDIR)$(LIBDIR) ]; then \
		mkdir -p $(DESTDIR)$(LIBDIR); \
	fi
	cp -r template lib $(DESTDIR)$(LIBDIR)
	@if [ ! -d $(DESTDIR)$(ETCDIR) ]; then \
		mkdir -p $(DESTDIR)$(ETCDIR); \
	fi
	@if [ ! -d $(MANDIR) ]; then \
		mkdir -p $(MANDIR); \
	fi
	cp vdradmind.pl.1 $(MANDIR)
	@if [ ! -d $(DESTDIR)$(DOCDIR) ]; then \
		mkdir -p $(DESTDIR)$(DOCDIR); \
	fi
	cp -r COPYING HISTORY* README* INSTALL contrib $(DESTDIR)$(DOCDIR)	
	for lang in $(LANGS); do \
	    [ ! -d $(LOCDIR)/$$lang/LC_MESSAGES/ ] && mkdir -p $(LOCDIR)/$$lang/LC_MESSAGES/; \
	    install -m 644 po/$$lang.mo $(LOCDIR)/$$lang/LC_MESSAGES/vdradmin.mo; \
	done

uninstall:
	if [ "$$(pidof -x vdradmind.pl)" ]; then \
		killall vdradmind.pl; \
	fi
	if [ -d $(DESTDIR)$(DOCDIR) ]; then \
		rm -rf $(DESTDIR)$(DOCDIR); \
	fi
	if [ -d $(DESTDIR)$(LIBDIR) ]; then \
		rm -rf $(DESTDIR)$(LIBDIR); \
	fi
	if [ -e $(MANDIR)/vdradmind.pl.1 ]; then \
		rm -f $(MANDIR)/vdradmind.pl.1; \
	fi
	if [ -e $(DESTDIR)$(BINDIR)/vdradmind.pl ]; then \
		rm -f $(DESTDIR)$(BINDIR)/vdradmind.pl; \
	fi
	for lang in $(LANGS); do \
	    if [ -e $(LOCDIR)/$$lang/LC_MESSAGES/vdradmin.mo ]; then \
				rm -f $(LOCDIR)/$$lang/LC_MESSAGES/vdradmin.mo; \
			fi; \
	done
	@echo ""
	@echo ""
	@echo "******************************"
	@echo "VDRAdmin has been uninstalled!"
	@echo ""
	@if [ -d $(DESTDIR)$(ETCDIR) ]; then \
		echo ""; \
		echo "Your configuration files located in $(DESTDIR)$(ETCDIR) have NOT been deleted!"; \
		echo "If you want to get rid of them, please delete them manually!"; \
	fi

