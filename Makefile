#
# Copyright (c) 2010 Mark Heily <mark@heily.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

.PHONY :: install uninstall check dist dist-upload publish-www clean merge distclean fresh-build rpm edit cscope valgrind

include config.mk

all: $(PROGRAM).so

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $(CFLAGS) $<

$(PROGRAM).a: $(OBJS)
	$(AR) rcs $(PROGRAM).a $(OBJS)

$(PROGRAM).so: $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) $(LDADD)
	$(LN) -sf $(PROGRAM).so.$(ABI_VERSION) $(PROGRAM).so
	$(LN) -sf $(PROGRAM).so.$(ABI_VERSION) $(PROGRAM).so.$(ABI_MAJOR)

test-$(PROGRAM): *.c *.h
	$(CC) $(CFLAGS) -g -O0 -o test-$(PROGRAM) -L. test.c -lpthread -lpthread_workqueue

install: $(PROGRAM).so
	$(INSTALL) -d -m 755 $(INCLUDEDIR)
	$(INSTALL) -d -m 755 $(LIBDIR)
	$(INSTALL) -m 644 $(HEADERS) $(INCLUDEDIR)
	$(INSTALL) -m 644 $(PROGRAM).so.$(ABI_VERSION) $(LIBDIR)
	$(LN) -sf $(PROGRAM).so.$(ABI_VERSION) $(LIBDIR)/$(PROGRAM).so.$(ABI_MAJOR)
	$(LN) -sf $(PROGRAM).so.$(ABI_VERSION) $(LIBDIR)/$(PROGRAM).so
	$(INSTALL) -d -m 755 $(MANDIR)/man3
	$(INSTALL) -m 644 pthread_workqueue.3 $(MANDIR)/man3/pthread_workqueue.3 

uninstall:
	rm -f $(INCLUDEDIR)/pthread_workqueue.h
	rm -f $(LIBDIR)/pthread_workqueue.so 
	rm -f $(LIBDIR)/pthread_workqueue.so.*
	rm -f $(LIBDIR)/pthread_workqueue.a
	rm -f $(MANDIR)/man3/pthread_workqueue.3 

reinstall: uninstall install
 
check: test-$(PROGRAM)
	LD_LIBRARY_PATH=. ./test-$(PROGRAM)

valgrind: test-$(PROGRAM)
	valgrind --tool=memcheck --leak-check=full --show-reachable=yes --num-callers=20 --track-fds=yes ./test-$(PROGRAM)

edit:
	$(EDITOR) `find ./ -name '*.c' -o -name '*.h'` Makefile

$(PROGRAM)-$(VERSION).tar.gz: 
	mkdir $(PROGRAM)-$(VERSION)
	cp  Makefile ChangeLog configure config.inc      \
        $(SOURCES) $(HEADERS)   \
        $(MANS) $(EXTRA_DIST)   \
        $(PROGRAM)-$(VERSION)
	tar zcf $(PROGRAM)-$(VERSION).tar.gz $(PROGRAM)-$(VERSION)
	rm -rf $(PROGRAM)-$(VERSION)

dist: $(PROGRAM)-$(VERSION).tar.gz

dist-upload: dist
	scp $(PROGRAM)-$(VERSION).tar.gz $(DIST)

publish-www:
	cp -R www/* ~/public_html/libkqueue/

clean:
	rm -f tags $(PROGRAM)-$(VERSION).tar.gz *.a $(OBJS) *.pc *.so *.so.* test-$(PROGRAM)
	rm -rf pkg

distclean: clean
	rm -f *.tar.gz config.mk config.h $(PROGRAM).pc $(PROGRAM).la rpm.spec
	rm -rf $(PROGRAM)-$(VERSION) 2>/dev/null || true

rpm: clean $(DISTFILE)
	rm -rf rpm *.rpm *.deb
	mkdir -p rpm/BUILD rpm/RPMS rpm/SOURCES rpm/SPECS rpm/SRPMS
	mkdir -p rpm/RPMS/i386 rpm/RPMS/x86_64
	cp $(DISTFILE) rpm/SOURCES 
	rpmbuild -bb rpm.spec
	mv ./rpm/RPMS/* .
	rm -rf rpm
	rmdir i386 x86_64    # WORKAROUND: These aren't supposed to exist
	fakeroot alien --scripts *.rpm

deb: clean $(DISTFILE)
	mkdir pkg
	cd pkg && tar zxf ../$(DISTFILE) 
	cp $(DISTFILE) pkg/$(PROGRAM)_$(VERSION).orig.tar.gz
	cp -R ports/debian pkg/$(PROGRAM)-$(VERSION) 
	cd pkg && \
	rm -rf `find $(PROGRAM)-$(VERSION)/debian -type d -name .svn` ; \
	perl -pi -e 's/\@\@VERSION\@\@/$(VERSION)/' $(PROGRAM)-$(VERSION)/debian/changelog ; \
	cd $(PROGRAM)-$(VERSION) && dpkg-buildpackage -uc -us
	lintian -i pkg/*.deb
	@printf "\nThe following packages have been created:\n"
	@find ./pkg -name '*.deb' | sed 's/^/    /'
