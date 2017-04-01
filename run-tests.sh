#!/bin/bash

CLANG_BIN=${CLANG_BIN:-clang}
CLANG_VERSION=$($CLANG_BIN --version)
PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')

echo "CLANG_BIN=$CLANG_BIN"
echo "CLANG_VERSION=$CLANG_VERSION"
echo "PYTHON_VERSION=$PYTHON_VERSION"
echo

function run_test {
    export TEST=$1

    echo $TEST

    # First check that ast2json.py can understand every line of the clang AST.
    $CLANG_BIN -Xclang -ast-dump -fsyntax-only $TEST | python ast2json.py > /tmp/0.txt
    if [ $? != 0 ]; then
        cat /tmp/0.txt
        exit 1
    fi

    # Compile with clang
    $CLANG_BIN -lm $TEST
    if [ $? != 0 ]; then
        exit 1
    fi
    
    # Run the program in a subshell so that the "Abort trap: 6" message is not
    # printed.
    $(echo "7" | ./a.out some args 2> /tmp/1-stderr.txt 1> /tmp/1-stdout.txt)
    C_EXIT_CODE=$?

    GO_FILES=$(python c2go.py $TEST)
    go build -o out $GO_FILES

    if [ $? != 0 ]; then
        echo "=== out.go"
        cat --number out.go
        exit 1
    fi

    # Run the program in a subshell so that the "Abort trap: 6" message is not
    # printed.
    $(echo "7" | ./out some args 2> /tmp/2-stderr.txt 1> /tmp/2-stdout.txt)
    GO_EXIT_CODE=$?

    if [ $C_EXIT_CODE -ne $GO_EXIT_CODE ]; then
        echo "ERROR: Received exit code $GO_EXIT_CODE from Go, but expected $C_EXIT_CODE."
        exit 1
    fi

    # Compare the output of the stdout and stderr from C and Go.
    diff /tmp/1-stderr.txt /tmp/2-stderr.txt
    diff /tmp/1-stdout.txt /tmp/2-stdout.txt
}

for TEST in ${@-$(find tests -name "*.c")}; do
    run_test $TEST
done
