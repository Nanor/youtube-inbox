#!/bin/bash

npm install coffee-loader coffee-script css file file-loader font-awesome font-awesome-webpack html-linkify ractive sass style url-loader webpack youtube-iframe css-loader sass-loader style-loader bootstrap less node-sass promise uglify

webpack

cd out
git init
git config user.name "Travis-CI"
git config user.email "ronan131@gmail.com"
git add .
git commit -m "Deploy to GitHub Pages"
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 2>&1
