#!/bin/bash

npm install coffee-loader
npm install coffee-script
npm install css
npm install file
npm install file-loader
npm install font-awesome
npm install font-awesome-webpack
npm install html-linkify
npm install ractive
npm install sass
npm install style
npm install url-loader
npm install webpack
npm install youtube-iframe
npm install css-loader
npm install sass-loader
npm install style-loader
npm install bootstrap

webpack

cd out
git init
git config user.name "Travis-CI"
git config user.email "ronan131@gmail.com"
git add .
git commit -m "Deploy to GitHub Pages"
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 2>&1
