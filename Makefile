# Makefile

SHELL := sh -e

LANGUAGES = de

SCRIPTS = bin/* hooks/* scripts/live scripts/live-functions scripts/live-helpers scripts/*/*

all: test build

test:
	@echo -n "Checking for syntax errors"

	@for SCRIPT in $(SCRIPTS); \
	do \
		sh -n $${SCRIPT}; \
		echo -n "."; \
	done

	@echo " done."

	@echo -n "Checking for bashisms"

	@# We can't just fail yet on bashisms (FIXME)
	@if [ -x /usr/bin/checkbashisms ]; \
	then \
		for SCRIPT in $(SCRIPTS); \
		do \
			checkbashisms $${SCRIPT} || true; \
			echo -n "."; \
		done; \
	else \
		echo "WARNING: skipping bashism test - you need to install devscripts."; \
	fi

	@echo " done."

build:
	@echo "Nothing to build."

install:
	# (FIXME)
	# Installing configuration
	install -D -m 0644 conf/live.conf $(DESTDIR)/etc/live.conf
	install -D -m 0644 conf/compcache $(DESTDIR)/usr/share/initramfs-tools/conf.d/compcache

	# Installing executables
	mkdir -p $(DESTDIR)/sbin
	cp bin/live-getty bin/live-login bin/live-new-uuid bin/live-snapshot bin/live-swapfile $(DESTDIR)/sbin

	mkdir -p $(DESTDIR)/usr/share/live-boot
	cp bin/live-preseed bin/live-reconfigure contrib/languagelist $(DESTDIR)/usr/share/live-boot

	mkdir -p $(DESTDIR)/usr/share/initramfs-tools
	cp -r hooks scripts $(DESTDIR)/usr/share/initramfs-tools

	# Installing docs
	mkdir -p $(DESTDIR)/usr/share/doc/live-boot
	cp -r COPYING docs/* $(DESTDIR)/usr/share/doc/live-boot

	mkdir -p $(DESTDIR)/usr/share/doc/live-boot/examples
	cp -r conf/* $(DESTDIR)/usr/share/doc/live-boot/examples
	# (FIXME)

	# Installing manpages
	for MANPAGE in manpages/en/*; \
	do \
		SECTION="$$(basename $${MANPAGE} | awk -F. '{ print $$2 }')"; \
		install -D -m 0644 $${MANPAGE} $(DESTDIR)/usr/share/man/man$${SECTION}/$$(basename $${MANPAGE}); \
	done

	for LANGUAGE in $(LANGUAGES); \
	do \
		for MANPAGE in manpages/$${LANGUAGE}/*; \
		do \
			SECTION="$$(basename $${MANPAGE} | awk -F. '{ print $$3 }')"; \
			install -D -m 0644 $${MANPAGE} $(DESTDIR)/usr/share/man/$${LANGUAGE}/man$${SECTION}/$$(basename $${MANPAGE} .$${LANGUAGE}.$${SECTION}).$${SECTION}; \
		done; \
	done

uninstall:
	# (FIXME)
	# Uninstalling configuration
	rm -f $(DESTDIR)/etc/live.conf

	# Uninstalling executables
	rm -f $(DESTDIR)/sbin/live-getty $(DESTDIR)/sbin/live-login $(DESTDIR)/sbin/live-snapshot $(DESTDIR)/sbin/live-swapfile
	rm -rf $(DESTDIR)/usr/share/live-boot
	rm -f $(DESTDIR)/usr/share/initramfs-tools/hooks/live
	rm -rf $(DESTDIR)/usr/share/initramfs-tools/scripts/live*
	rm -f $(DESTDIR)/usr/share/initramfs-tools/scripts/local-top/live

	# Uninstalling docs
	rm -rf $(DESTDIR)/usr/share/doc/live-boot
	# (FIXME)

	# Uninstalling manpages
	for MANPAGE in manpages/en/*; \
	do \
		SECTION="$$(basename $${MANPAGE} | awk -F. '{ print $$2 }')"; \
		rm -f $(DESTDIR)/usr/share/man/man$${SECTION}/$$(basename $${MANPAGE} .en.$${SECTION}).$${SECTION}; \
	done

	for LANGUAGE in $(LANGUAGES); \
	do \
		for MANPAGE in manpages/$${LANGUAGE}/*; \
		do \
			SECTION="$$(basename $${MANPAGE} | awk -F. '{ print $$3 }')"; \
			rm -f $(DESTDIR)/usr/share/man/$${LANGUAGE}/man$${SECTION}/$$(basename $${MANPAGE} .$${LANGUAGE}.$${SECTION}).$${SECTION}; \
		done; \
	done

clean:

distclean:

reinstall: uninstall install
