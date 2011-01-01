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

	@# We can't just fail yet on bashisms (FIXME)
	@if [ -x "$$(which checkbashisms 2>/dev/null)" ]; \
	then \
		echo -n "Checking for bashisms"; \
		for SCRIPT in $(SCRIPTS); \
		do \
			checkbashisms -f -x $${SCRIPT} || true; \
			echo -n "."; \
		done; \
		echo " done."; \
	else \
		echo "W: checkbashisms - command not found"; \
		echo "I: checkbashisms can be optained from: "; \
		echo "I:   http://git.debian.org/?p=devscripts/devscripts.git"; \
		echo "I: On Debian systems, checkbashisms can be installed with:"; \
		echo "I:   apt-get install devscripts"; \
	fi

build:
	@echo "Nothing to build."

install:
	# Installing executables
	mkdir -p $(DESTDIR)/bin
	cp bin/live-system $(DESTDIR)/bin

	mkdir -p $(DESTDIR)/sbin
	cp bin/live-new-uuid bin/live-snapshot bin/live-swapfile bin/live-toram $(DESTDIR)/sbin

	mkdir -p $(DESTDIR)/usr/share/live-boot
	cp bin/live-preseed bin/live-reconfigure local/languagelist $(DESTDIR)/usr/share/live-boot

	mkdir -p $(DESTDIR)/usr/share/initramfs-tools
	cp -r hooks scripts $(DESTDIR)/usr/share/initramfs-tools

	# Installing docs
	mkdir -p $(DESTDIR)/usr/share/doc/live-boot
	cp -r COPYING docs/* $(DESTDIR)/usr/share/doc/live-boot

	mkdir -p $(DESTDIR)/usr/share/doc/live-boot/examples
	cp -r etc/* $(DESTDIR)/usr/share/doc/live-boot/examples
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
	# Uninstalling executables
	rm -f $(DESTDIR)/sbin/live-snapshot $(DESTDIR)/sbin/live-swapfile $(DESTDIR)/bin/live-system $(DESTDIR)/sbin/live-toram
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/sbin

	rm -rf $(DESTDIR)/usr/share/live-boot

	rm -f $(DESTDIR)/usr/share/initramfs-tools/hooks/live
	rm -rf $(DESTDIR)/usr/share/initramfs-tools/scripts/live*
	rm -f $(DESTDIR)/usr/share/initramfs-tools/scripts/local-top/live

	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/initramfs-tools/hooks
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/initramfs-tools/scripts/local-top
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/initramfs-tools/scripts
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/initramfs-tools
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr

	# Uninstalling docs
	rm -rf $(DESTDIR)/usr/share/doc/live-boot
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/doc
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr

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

	for SECTION in $(ls manpages/en/* | awk -F. '{ print $2 }'); \
	do \
		rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/man/man$${SECTION} || true; \
		rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/man/*/man$${SECTION} || true; \
	done

	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/man || true
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share || true
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr || true

	rmdir --ignore-fail-on-non-empty $(DESTDIR) || true

clean:
	@echo "Nothing to clean."

distclean: clean
	@echo "Nothing to distclean."

reinstall: uninstall install
