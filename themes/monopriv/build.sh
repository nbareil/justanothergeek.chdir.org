apk add git
git clone https://github.com/gohugoio/hugobasicexample.git && mkdir -p hugobasicexample/themes/monopriv
cp -r archetypes exampleSite images layouts resources static theme.toml hugobasicexample/themes/monopriv/ && ls
cd hugobasicexample/
mv themes/monopriv/exampleSite/config.toml .
hugo -b https://kskarthik.gitlab.io/monopriv/
