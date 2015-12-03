#!/bin/bash

# Basically from https://medium.com/philosophy-logic/publishing-gh-pages-with-travis-ci-53a8270e87db

npm install -g coffee-script
gem install sass

rm -rf out || exit 0;
mkdir out;

cp src/index.html out/
sass --sourcemap=none src/index.sass out/index.css
coffee --compile --output out/ src/
cp src/libraries out/ -rf

cd out
git init
git config user.name "Travis-CI"
git config user.email "ronan131@gmail.com"
git add .
git commit -m "Deploy to GitHub Pages"
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 2>&1