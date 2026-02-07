#!/bin/bash

# CLI Parser Test Script
# Run with: ./test.sh

PROGRAM="odin run . --"

echo "========================================"
echo "CLI Parser Test Suite"
echo "========================================"

echo ""
echo "--- Test 1: Normal usage (should succeed) ---"
$PROGRAM --verbose -o out.txt file1.txt file2.txt -vvv
echo ""

echo "--- Test 2: Help flag ---"
$PROGRAM --help
echo ""

echo "--- Test 3: Missing required option (should error) ---"
$PROGRAM file1.txt file2.txt
echo ""

echo "--- Test 4: Missing required positional (should error) ---"
$PROGRAM --output out.txt
echo ""

echo "--- Test 5: Unknown flag (should error) ---"
$PROGRAM --unknown file1.txt
echo ""

echo "--- Test 6: Unknown short flag (should error) ---"
$PROGRAM -x file1.txt
echo ""

echo "--- Test 7: Option without value (should error) ---"
$PROGRAM --output
echo ""

echo "--- Test 8: Short option without value (should error) ---"
$PROGRAM -o
echo ""

echo "--- Test 9: Duplicate option (should error) ---"
$PROGRAM -o one.txt -o two.txt file.txt
echo ""

echo "--- Test 10: Long form with equals ---"
$PROGRAM --output=result.txt file1.txt
echo ""

echo "--- Test 11: Counting flags ---"
$PROGRAM -o out.txt file.txt -vvvvv
echo ""

echo "--- Test 12: Help in the middle (should show help and exit) ---"
$PROGRAM -o out.txt --help file.txt
echo ""

echo "========================================"
echo "Edge Cases (TODO)"
echo "========================================"

echo ""
echo "--- Edge 1: Just a dash ---"
$PROGRAM -o out.txt - file.txt
echo ""

echo "--- Edge 2: Double dash alone ---"
$PROGRAM -o out.txt -- file.txt
echo ""

echo "--- Edge 3: Empty value with equals ---"
$PROGRAM --output= file.txt
echo ""

echo "========================================"
echo "Tests complete"
echo "========================================"
