#!/bin/bash
nb_leaves=$1

# directory to store docs
DOCS="./docs"

# clean docs directory
rm "$DOCS"/*

for ((i = 0; i <= nb_leaves; i++)); do
    touch "$DOCS/doc$i.txt" && echo "$i$i$i" >"$DOCS/doc$i.txt"
done
