#!/bin/bash

git init duckdb
cd duckdb
git remote add origin https://github.com/duckdb/duckdb.git
git fetch --depth 1 origin tag v0.10.1
git fetch --depth 1 origin tag v0.10.2

