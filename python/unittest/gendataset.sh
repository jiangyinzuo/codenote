#!/bin/bash

noterepo0=unittest/duckdb-noterepo-v0.10.1-nocommit
noterepo1=unittest/duckdb-noterepo-v0.10.1-after-saving
noterepo2=unittest/duckdb-noterepo-v0.10.2
noterepo2_manual=unittest/duckdb-noterepo-v0.10.2-manual-update

cleanup_noterepo0() {
	pushd $noterepo0
	rm -f codenote-duckdb.db
	git restore .
	popd
}

cleanup_noterepo0

pushd unittest/duckdb
git checkout v0.10.1
popd

rm -rf $noterepo1 $noterepo2

# generate $noterepo1
(set -x; python3 codenote.py --noterepo=$noterepo0 save --coderepo=./unittest/duckdb      --commit=v0.10.1)
cp -r $noterepo0 $noterepo1

pushd unittest/duckdb
git checkout v0.10.2
popd

# generate $noterepo2
(set -x; python3 codenote.py --noterepo=$noterepo0 rebase --coderepo=./unittest/duckdb      --commit=v0.10.2)
cp -r $noterepo0 $noterepo2

cleanup_noterepo0

# check consistency
(set -x; python3 codenote.py --noterepo=$noterepo2_manual check --coderepo=./unittest/duckdb      --commit=v0.10.2)
if [[ $? -ne 0 ]]; then
	echo "Error: $noterepo2_manual is not consistent with unittest/duckdb"
	exit 1
else
	echo "$noterepo2_manual is consistent with unittest/duckdb"
fi

