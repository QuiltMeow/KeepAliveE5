#!/usr/bin/env bash

[ "$(command -v git.exe)" ] && git=git.exe || git=git

$git config user.name github-actions
$git config user.email github-actions@github.com

$git checkout --orphan latest_branch
$git rm -rf --cached .
$git add -A
$git commit -m "$1"
$git branch -D master
$git branch -m master
$git push -f origin master
