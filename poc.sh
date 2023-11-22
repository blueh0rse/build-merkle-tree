#!/bin/bash

#        node2.0 (root)
#   node1.0       node1.1
# doc0   doc1   doc2   doc3

# directories
DOCS="./docs"
NODES="./nodes"

# prefix files
PRE_DOCS="doc.pre"
PRE_NODE="./node.pre"

# synthese file
OUTPUT="./tree.txt"

# compute docs hashes
echo "Computing documents hashes..."
cat $PRE_DOCS $DOCS/doc0.txt | openssl dgst -sha1 -binary | xxd -p >$NODES/node0.0
cat $PRE_DOCS $DOCS/doc1.txt | openssl dgst -sha1 -binary | xxd -p >$NODES/node0.1
cat $PRE_DOCS $DOCS/doc2.txt | openssl dgst -sha1 -binary | xxd -p >$NODES/node0.2
cat $PRE_DOCS $DOCS/doc3.txt | openssl dgst -sha1 -binary | xxd -p >$NODES/node0.3

# compute nodes hashes
echo "Computing nodes hashes..."
cat $NODES/node0.0 $NODES/node0.1 | openssl dgst -sha1 -binary | xxd -p >$NODES/node1.0
cat $NODES/node0.2 $NODES/node0.3 | openssl dgst -sha1 -binary | xxd -p >$NODES/node1.1

# compute root node hash
echo "Computing root node hash..."
cat $NODES/node1.0 $NODES/node1.1 | openssl dgst -sha1 -binary | xxd -p >$NODES/node2.0

# generate synthese
echo "Generating synthese file..."

name="MerkleNODES"
algo="sha1"
doc_prefix=$(cat $PRE_DOCS)
node_prefix="$(cat $PRE_NODE)"
nb_docs="$(ls $DOCS -1q | wc -l)"
nb_layer=3
root_hash=$(cat $NODES/node2.0)

# write header
echo "$name:$algo:$doc_prefix:$node_prefix:$nb_docs:$nb_layer:$root_hash" >$OUTPUT

# write nodes values
echo 0:0:$(cat $NODES/node0.0) >>$OUTPUT
echo 0:1:$(cat $NODES/node0.0) >>$OUTPUT
echo 0:2:$(cat $NODES/node0.0) >>$OUTPUT
echo 0:3:$(cat $NODES/node0.0) >>$OUTPUT
echo 1:0:$(cat $NODES/node0.0) >>$OUTPUT
echo 1:1:$(cat $NODES/node0.0) >>$OUTPUT

echo "Done!"

mkdir -p root/node1.0/node0.0 root/node1.0/node0.1 root/node1.1/node0.2 root/node1.1/node0.3

echo "Tree looks like:"

tree root --noreport
