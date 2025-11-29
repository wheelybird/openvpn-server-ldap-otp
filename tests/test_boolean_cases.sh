#!/bin/bash

# Test case-insensitive boolean handling
# This script tests various case combinations of boolean values

set -e

echo "Testing case-insensitive boolean handling..."
echo

# Test function for boolean comparisons
test_boolean() {
  local test_value="$1"
  local expected="$2"
  local test_name="$3"

  if [ "${test_value,,}" == "true" ]; then
    result="true"
  else
    result="false"
  fi

  if [ "$result" == "$expected" ]; then
    echo "✓ PASS: $test_name - '$test_value' -> $result"
  else
    echo "✗ FAIL: $test_name - '$test_value' -> $result (expected $expected)"
    exit 1
  fi
}

# Test TRUE variations
echo "Testing TRUE variations:"
test_boolean "true" "true" "lowercase true"
test_boolean "TRUE" "true" "uppercase TRUE"
test_boolean "True" "true" "capitalised True"
test_boolean "TrUe" "true" "mixed case TrUe"
test_boolean "tRuE" "true" "mixed case tRuE"

echo

# Test FALSE variations
echo "Testing FALSE variations:"
test_boolean "false" "false" "lowercase false"
test_boolean "FALSE" "false" "uppercase FALSE"
test_boolean "False" "false" "capitalised False"
test_boolean "FaLsE" "false" "mixed case FaLsE"
test_boolean "fAlSe" "false" "mixed case fAlSe"

echo

# Test other values (should be treated as false)
echo "Testing other values (should be treated as false):"
test_boolean "" "false" "empty string"
test_boolean "yes" "false" "yes"
test_boolean "no" "false" "no"
test_boolean "1" "false" "1"
test_boolean "0" "false" "0"

echo
echo "All tests passed!"
