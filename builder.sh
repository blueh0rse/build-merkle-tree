#!/bin/bash
# set -x

# directories
DOCS="docs"
NODES="nodes"

# prefix files
PRE_DOCS="doc.pre"
PRE_NODE="node.pre"

# synthese file
OUTPUT_FILE="tree.txt"

function initialization() {
    # Check if directories exist, create them if not
    [ -d "$DOCS" ] || mkdir "$DOCS" || echo "Creating $DOCS..."
    [ -d "$NODES" ] || mkdir "$NODES" || echo "Creating $NODES..."

    # Check if necessary files exist
    [ -f "$PRE_DOCS" ] || {
        echo "$PRE_DOCS not found"
        exit 1
    }
    [ -f "$PRE_NODE" ] || {
        echo "$PRE_NODE not found"
        exit 1
    }

    # get number of documents
    nb_leaves="$(find "$DOCS" -maxdepth 1 -type f | wc -l)"

    # calculate layers
    nb_layers=$(echo "l($nb_leaves)/l(2)" | bc -l)
    # round to nearest integer
    nb_layers=$(printf "%.0f" "$nb_layers")
    # add 1 for root
    nb_layers=$(($nb_layers + 1))

    echo "Tree has $nb_leaves leaves: need $nb_layers layers."
}

function clean_dirs() {
    # empty docs directory
    rm -rf "${DOCS:?}"/* || {
        echo "Error clearing $NODES directory"
        exit 1
    }
    # empty nodes directory
    rm -rf "${NODES:?}"/* || {
        echo "Error clearing $NODES directory"
        exit 1
    }
}

function generate_documents() {
    arg=$1
    nb_leaves=$((arg - 1))

    # directory to store documents
    DOCS="./docs"

    # check if directory exists
    if [ ! -d "$DOCS" ]; then
        # if not create it
        mkdir "$DOCS"
        if [ $? -ne 0 ]; then
            echo "Error while creating $DOCS"
            exit 1
        fi
    else
        # clean directory
        rm -rf "${DOCS:?}"/*
        if [ $? -ne 0 ]; then
            echo "Error while cleaning $DOCS"
            exit 1
        fi
    fi

    # create files
    for ((i = 0; i <= nb_leaves; i++)); do
        touch "$DOCS/doc$i.txt"
        if [ $? -ne 0 ]; then
            echo "Error while creating doc$i.txt"
            exit 1
        fi
        echo "$i$i$i" >"$DOCS/doc$i.txt"
    done
}

function generate_leaves() {
    # node order
    local j=0

    for file in "$DOCS"/*; do
        # Check if file is file
        if [ -f "$file" ]; then
            # compute hash using prefix
            cat "$PRE_DOCS" "$file" | openssl dgst -sha1 -binary | xxd -p >"$NODES/node0.$j" || {
                echo "Error in generating hash for $file"
                exit 1
            }
        fi
        j=$((j + 1))
    done

    echo "Documents transformed into leaves successfully"
}

function generate_tree() {
    # node layer
    local i=$1
    # next layer
    local ii=$((i + 1))
    # node position
    local j=0
    # number of nodes to process
    local nb_nodes=0
    # processed node node_counter
    local c=0

    nb_nodes=$(find "$NODES" -maxdepth 1 -type f -name "node$i.*" | wc -l)

    if ((nb_nodes == 1)); then
        echo "Tree generation done!"
        return
    fi

    for file in "$NODES"/*; do
        # if element is a file
        if [ -f "$file" ]; then

            # if node layer equals i
            if [[ $file == "$NODES/node$i."* ]]; then

                # create pairs
                if ((c % 2 == 0)); then
                    :
                else
                    # compute hashes
                    previous_file=$(echo "$NODES"/* | cut -d ' ' -f $c)
                    echo "Computing $previous_file & $file into $NODES/node$ii.$j"
                    test=$(cat "$PRE_NODE" "$previous_file" "$file" | openssl dgst -sha1 -binary | xxd -p)
                    echo "$test"
                    cat "$PRE_NODE" "$previous_file" "$file" | openssl dgst -sha1 -binary | xxd -p >"$NODES/node$ii.$j" || {
                        echo "Error in generating hash for pair $previous_file & $file"
                        exit 1
                    }
                    # increment next free node position
                    j=$((j + 1))
                fi

                # if last layer file is alone
                if ((nb_nodes % 2 != 0 && c == (nb_nodes - 1))); then
                    echo "$file has no pair, computing into $NODES/node$ii.$j"
                    cat "$PRE_NODE" "$file" | openssl dgst -sha1 -binary | xxd -p >"$NODES/node$ii.$j" || {
                        echo "Error in generating hash for $file"
                        exit 1
                    }
                fi

                # increment number of processed nodes
                c=$((c + 1))

                if ((c == nb_nodes)); then
                    echo "Layer $i done, moving to layer $ii"
                    # end of layer
                    generate_tree $ii
                fi
            fi
        fi
    done
}

function generate_synthesis() {
    # get missing variables
    name="MerkleTree"
    algo="sha1"
    doc_prefix="$(cat $PRE_DOCS)"
    node_prefix="$(cat $PRE_NODE)"
    root_hash="$(tail -n 1 $NODES/* | tail -n 1)"

    # write header
    echo "$name:$algo:$doc_prefix:$node_prefix:$nb_leaves:$nb_layers:$root_hash" >$OUTPUT_FILE

    # write nodes values
    # get master node
    # last_file=$(ls -1 "$NODES" | tail -n 1)

    # Sort files numerically and process them
    for file in $(ls "$NODES"/ | sort -V); do
        full_path="$NODES/$file"
        # extract the 'layer.order' part from the file name
        if [[ $file =~ ([0-9]+\.[0-9]+)$ ]]; then
            node_order=${BASH_REMATCH[1]}
            # replace '.' with ':'
            node_order=$(echo "$node_order" | tr '.' ':')
            echo "$node_order:$(cat "$full_path")" >>$OUTPUT_FILE
        fi
    done
}

function update_tree() {
    # Get the number of the new document
    local new_doc_number=$(find "$DOCS" -type f | wc -l)
    local new_doc="$DOCS/doc$new_doc_number.txt"

    # Create and hash the new document
    echo "$new_doc_number$new_doc_number$new_doc_number" >"$new_doc"
    local new_leaf_hash=$(cat "$PRE_DOCS" "$new_doc" | openssl dgst -sha1 -binary | xxd -p)
    echo "$new_leaf_hash" >"$NODES/node0.$new_doc_number"

    # Update necessary nodes
    local i=0
    local current_node_index=$new_doc_number
    local parent_node_index=$((current_node_index / 2))

    while :; do
        if ((current_node_index % 2)); then
            # If current node is odd, its pair is to the left
            local sibling_node="$NODES/node$i.$((current_node_index - 1))"
            local current_node="$NODES/node$i.$current_node_index"
            local parent_node="$NODES/node$((i + 1)).$parent_node_index"

            if [ -f "$sibling_node" ]; then
                cat "$PRE_NODE" "$sibling_node" "$current_node" | openssl dgst -sha1 -binary | xxd -p >"$parent_node"
            else
                # Sibling does not exist, move current node up
                cp "$current_node" "$parent_node"
            fi
        else
            # If current node is even, update only if there is a sibling
            local sibling_node="$NODES/node$i.$((current_node_index + 1))"
            local current_node="$NODES/node$i.$current_node_index"
            local parent_node="$NODES/node$((i + 1)).$parent_node_index"

            if [ -f "$sibling_node" ]; then
                cat "$PRE_NODE" "$current_node" "$sibling_node" | openssl dgst -sha1 -binary | xxd -p >"$parent_node"
            else
                # No sibling, no need to update parent
                break
            fi
        fi

        # Move to the next layer
        i=$((i + 1))
        current_node_index=$parent_node_index
        parent_node_index=$((parent_node_index / 2))
    done

    # Update the synthese file
    generate_synthesis
}

function generate_proof() {
    local doc_index=$1
    local proof_file="proof_$doc_index.txt"
    local current_layer=0
    local current_node_index=$doc_index

    # Start a new proof file or clear the existing one
    >"$proof_file"

    # Traverse up the tree and collect sibling hashes
    while [[ $current_layer -lt $nb_layers ]]; do
        local sibling_index
        # Calculate sibling index based on whether node index is odd or even
        if ((current_node_index % 2)); then
            sibling_index=$((current_node_index - 1))
        else
            sibling_index=$((current_node_index + 1))
        fi

        local sibling_node="$NODES/node$current_layer.$sibling_index"

        # Debugging information
        echo "Current layer: $current_layer, Current node index: $current_node_index, Sibling node: $sibling_node"

        # Check if sibling node exists
        if [ -f "$sibling_node" ]; then
            # Append the sibling hash and its position to the proof file
            echo "node$current_layer.$sibling_index:$(cat "$sibling_node")" >>"$proof_file"
        fi

        # Prepare for the next iteration
        current_layer=$((current_layer + 1))
        current_node_index=$((current_node_index / 2))
    done

    echo "Proof of membership generated in $proof_file"
}

function verify_proof() {
    local doc_index=$1
    local proof_file=$2
    local doc_file="$DOCS/doc$doc_index.txt"
    local synthesis_file="$OUTPUT_FILE"

    # Read public information from tree.txt
    local public_info=$(head -n 1 "$synthesis_file")
    local root_hash=$(echo "$public_info" | cut -d ':' -f 7)

    # Compute the hash of the document
    local doc_hash=$(cat "$PRE_DOCS" "$doc_file" | openssl dgst -sha1 -binary | xxd -p)

    # Initialize the computed hash with the document's hash
    local computed_hash="$doc_hash"

    # Process each line in the proof file
    while read -r line; do
        # Extract node info and hash
        local node_info=$(echo "$line" | cut -d ':' -f 1)
        local node_hash=$(echo "$line" | cut -d ':' -f 2)
        computed_hash=$(echo "$PRE_NODE" "$computed_hash" "$node_hash" | openssl dgst -sha1 -binary | xxd -p)
        current_layer=$((current_layer + 1))
    done <"$proof_file"

    # Verify if the computed hash matches the root hash
    if [ "$computed_hash" == "$root_hash" ]; then
        echo "Verification successful: Document at position $doc_index is part of the Merkle Tree."
    else
        echo "Verification failed: Document at position $doc_index is not part of the Merkle Tree."
    fi
}

function main() {
    initialization
    # mode selection
    if [ "$1" == "build" ]; then
        echo "You want to build a tree."
        # generates documents
        generate_documents "$2"
        # generate documents hashes
        generate_leaves
        # generate all node layers
        generate_tree 0
        # generate synthese
        generate_synthesis
        # build function
    elif [ "$1" == "update" ]; then
        echo "You want to update an existing tree."
        # update function
        update_tree
    elif [ "$1" == "gproof" ]; then
        generate_proof "$2"
    elif [ "$1" == "vproof" ]; then
        verify_proof "$2" "$3"
    elif [ "$1" == "clean" ]; then
        clean_dirs
    fi

}

main "$@"
