HUGO_VERSION=0.66.0

build: deps
	./binaries/hugo -v -b http://www.lucassabreu.net.br

serve: deps
	./binaries/hugo server --bind=0.0.0.0 -b "http://lucassabreu.test" --buildDrafts

deps: binaries/hugo themes/after-dark/.git

themes/after-dark/.git:
	git submodule update --init

binaries/hugo:
	mkdir -p binaries
	curl --location http://github.com/spf13/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz -o hugo_${HUGO_VERSION}_Linux-64bit.tar.gz
	tar xvzf hugo_${HUGO_VERSION}_Linux-64bit.tar.gz -C binaries
	rm hugo_${HUGO_VERSION}_Linux-64bit.tar.gz
	chmod +x binaries/hugo
