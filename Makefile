# Makefile

CFLAGS = -Wall -g -O2
BUILD_SYSTEM := $(shell lsb_release --short --id)

TRANSLATIONS=""

all: build

test:
	set -e; for SCRIPT in hooks/* scripts/live scripts/live-functions scripts/live-helpers scripts/*/*; \
	do \
		sh -n $$SCRIPT; \
	done

build:
	# Setting BUILD_SYSTEM
	sed -e 's/\(BUILD_SYSTEM="\).*"/\1'$(BUILD_SYSTEM)'"/g' conf/live.conf > live.conf

	# Building live-md5check
	CFLAGS="$(CFLAGS)" $(MAKE) -C bin/live-md5check

install: test build
	# Installing configuration
	install -D -m 0644 live.conf $(DESTDIR)/etc/live.conf

	# Installing live-md5check
	install -D -m 0755 bin/live-md5check/live-md5check $(DESTDIR)/usr/lib/live-initramfs/live-md5check

	# Installing executables
	mkdir -p $(DESTDIR)/sbin
	cp bin/live-getty bin/live-login bin/live-snapshot $(DESTDIR)/sbin

	mkdir -p $(DESTDIR)/usr/share/live-initramfs
	cp bin/live-preseed bin/live-reconfigure $(DESTDIR)/usr/share/live-initramfs

	mkdir -p $(DESTDIR)/usr/share/initramfs-tools
	cp -r hooks scripts $(DESTDIR)/usr/share/initramfs-tools

	# Installing documentation
	mkdir -p $(DESTDIR)/usr/share/doc/live-initramfs
	cp -r COPYING docs/* $(DESTDIR)/usr/share/doc/live-initramfs

	mkdir -p $(DESTDIR)/usr/share/doc/live-initramfs/examples
	cp -r conf/live.conf $(DESTDIR)/usr/share/doc/live-initramfs/examples

	# Installing manpages
	set -e; for MANPAGE in manpages/*.en.1; \
	do \
		install -D -m 0644 $$MANPAGE $(DESTDIR)/usr/share/man/man1/`basename $$MANPAGE .en.1`.1; \
	done

	set -e; for MANPAGE in manpages/*.en.7; \
	do \
		install -D -m 0644 $$MANPAGE $(DESTDIR)/usr/share/man/man7/`basename $$MANPAGE .en.7`.7; \
	done

	set -e; for TRANSLATIONS in $$TRANSLATIONS; \
	do \
		for MANPAGE in manpages/*.$$TRANSLATION.1; \
		do \
			install -D -m 0644 $$MANPAGE $(DESTDIR)/usr/share/man/$$TRANSLATION/man1/`basename $$MANPAGE .$$TRANSLATION.1`.1; \
		done; \
		for MANPAGE in manpages/*.$$TRANSLATION.7; \
		do \
			install -D -m 0644 $$MANPAGE $(DESTDIR)/usr/share/man/$$TRANSLATION/man7/`basename $$MANPAGE .$$TRANSLATION.7`.7; \
		done; \
	done

	# Temporary symlinks
	ln -sf live-initramfs.7.gz $(DESTDIR)/usr/share/man/man7/live-getty.7.gz
	ln -sf live-initramfs.7.gz $(DESTDIR)/usr/share/man/man7/live-login.7.gz

uninstall:
	# Uninstalling configuration
	rm -f $(DESTDIR)/etc/live.conf

	# Uninstalling live-md5check
	rm -rf $(DESTDIR)/usr/lib/live-initramfs

	# Uninstalling executables
	rm -f $(DESTDIR)/sbin/live-getty $(DESTDIR)/sbin/live-login $(DESTDIR)/sbin/live-snapshot
	rm -rf $(DESTDIR)/usr/share/live-initramfs
	rm -f $(DESTDIR)/usr/share/initramfs-tools/hooks/live
	rm -rf $(DESTDIR)/usr/share/initramfs-tools/scripts/live*

	# Uninstalling documentation
	rm -rf $(DESTDIR)/usr/share/doc/live-initramfs

	# Uninstalling manpages
	set -e; for MANPAGE in manpages/*.en.1; \
	do \
		rm -f $(DESTDIR)/usr/share/man/man1/`basename $$MANPAGE .en.1`.1; \
	done

	set -e; for MANPAGE in manpages/*.en.7; \
	do \
		rm -f $(DESTDIR)/usr/share/man/man7/`basename $$MANPAGE .en.7`.7; \
	done

	set -e; for TRANSLATIONS in $$TRANSLATIONS; \
	do \
		for MANPAGE in manpages/*.$$TRANSLATION.1; \
		do \
			install -D -m 0644 $$MANPAGE $(DESTDIR)/usr/share/man/$$TRANSLATION/man1/`basename $$MANPAGE .$$TRANSLATION.1`.1; \
		done; \
		for MANPAGE in manpages/*.$$TRANSLATION.7; \
		do \
			install -D -m 0644 $$MANPAGE $(DESTDIR)/usr/share/man/$$TRANSLATION/man7/`basename $$MANPAGE .$$TRANSLATION.7`.7; \
		done; \
	done

	# Temporary symlinks
	rm -f $(DESTDIR)/usr/share/man/man7/live-getty.7.gz
	rm -f $(DESTDIR)/usr/share/man/man7/live-login.7.gz

update:
	set -e; for MANPAGE in manpages/*.en.*; \
	do \
		sed -i	-e 's/2007\\-06\\-25/2007\\-07\\-02/' \
			-e 's/1.91.2/1.91.3/' \
		$$MANPAGE; \
	done

clean:
	rm -f live.conf
	$(MAKE) -C bin/live-md5check clean

distclean:

reinstall: uninstall install
