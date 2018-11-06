#! /bin/bash

LIBDIR="$1"

for F in "$LIBDIR"/*.dylib; do

	L=$(otool -l "$F" | grep -n LC_VERSION_MIN_MACOSX | cut -d':' -f 1)
	V=$(otool -l "$F" | tail -n +${L} | grep version | head -n 1 | tr -s ' ' | cut -d' ' -f 3)
	echo "$V    $(basename "$F")"

done