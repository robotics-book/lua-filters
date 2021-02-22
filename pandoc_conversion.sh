#!/bin/bash
# usage example: bash pandoc_conversion.sh robotics.bib ch*_00.tex
FILES="$@"
arr=($FILES)
for f in "${arr[@]:1}"
do
	g="${f%.*}"
	echo "Processing $f file..."
	pandoc "$f" -f latex+raw_tex -t markdown -o "$g".md --markdown-headings=atx --top-level-division=chapter --citeproc --bibliography="${arr[0]}" --lua-filter tikz.lua --lua-filter keyword.lua
done

