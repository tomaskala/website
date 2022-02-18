.POSIX:
.SUFFIXES:

PANDOC_ARGS = --template parts/template.html -B parts/header.html -A parts/footer.html --standalone --shift-heading-level-by 1
PARTS = $(shell ls parts/*.html)
MARKDOWN = $(shell find . -type f -not -name 'README.md' -name '*.md')
HTML = $(MARKDOWN:.md=.html)
HTML += index.html

.PHONY: all
all: $(HTML)

$(HTML): $(PARTS)

index.md: fill-index
	./fill-index

.PHONY: clean
clean:
	find . -type f -not -path './parts/*' -name '*.html' -exec rm {} \+
	rm -f index.md

.PHONY: sync
sync:
	rsync -auzv --exclude .git --include '*/' --include '*.html' --include 'parts/*.html' --include 'static/*' --include 'posts/*.html' --exclude '*' . dale:/var/www/tomaskala.com

.SUFFIXES: .md .html
.md.html:
	pandoc --from markdown --to html $(PANDOC_ARGS) $< -o $@
