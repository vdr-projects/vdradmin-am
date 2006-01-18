DESTDIR=
LIBDIR=/usr/share/vdradmin
ETCDIR=/etc/vdradmin
DOCDIR=/usr/share/doc/vdradmin
BINDIR=/usr/bin
LOCDIR=/usr/share/locale/
MANDIR=/usr/share/man/man1/
LOGDIR=/var/log
PIDFILE=/var/run/vdradmind.pid
VIDEODIR=/video
EPGIMAGES=$(VIDEODIR)/epgimages
VDRCONF=$(VIDEODIR)
EPGDATA=$(VIDEODIR)/epg.data

LANGS=de es fr fi nl

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
	@./install.sh -c

uninstall:
	@./uninstall.sh

