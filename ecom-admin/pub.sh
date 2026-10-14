#!/usr/bin/env bash
pnpm build --emptyOutDir

version="$(git symbolic-ref --short -q HEAD)"
hash="$(git rev-parse --short HEAD)"
date="$(git show -s --format=%cI)"
author="$(git show -s --format=%an)"
commit="$(git log --pretty=format:'%s' -1)"

if [[ $version =~ "/" ]] ; then
   filename="$(echo $version | awk -F/ '{print $NF}')"
    filename="${filename//./}"
else
    filename=$version
fi

if [[ $filename = "developer" ]] || [[ $filename = "master" ]] ; then
    filename="dist"
fi

echo -----------------------------
echo $filename
echo -----------------------------

cd ../ecom-admin-publish || exit
git pull
git add .
git commit -m "$commit - $version:$hash|$author:$date"
git push
# 测试版本更新
# curl -i "http://10.200.16.50:9401/sync_dist.php?dir=$filename"
# 正式版本更新

cd ../ecom-admin-frontend || exit

echo "完成- $commit - $version:$hash|$author:$date -更新"


