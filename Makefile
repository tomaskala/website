.POSIX:
.SUFFIXES:

.PHONY: build
build:
	hugo

.PHONY: clean
clean:
	rm -r public

.PHONY: sync
sync: build
	rsync -auzv --delete public/ whitelodge:/var/www/tomaskala.com
