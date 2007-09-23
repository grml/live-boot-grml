all: doc

doc: doc_man doc_html

doc_html: html-stamp

html-stamp: live-initramfs.en.7.txt
	asciidoc -b xhtml11 -a icons live-initramfs.en.7.txt
	touch html-stamp

doc_man: man-stamp

man-stamp: live-initramfs.en.7.txt

	asciidoc -d manpage -b docbook live-initramfs.en.7.txt
	xsltproc /usr/share/xml/docbook/stylesheet/nwalsh/manpages/docbook.xsl live-initramfs.en.7.xml
	mv live-initramfs.7 live-initramfs.en.7
	touch man-stamp

clean:
	rm -f live-initramfs.en.7.html live-initramfs.en.7.xml live-initramfs.en.7 html-stamp man-stamp
