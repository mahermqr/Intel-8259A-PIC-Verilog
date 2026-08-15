#!/usr/bin/env bash
# Bash Script: run_sim.sh
# Runs Icarus Verilog simulation suite for Intel 8259A PIC

set -e
cd "$(dirname "$0")/.."

echo "Running Python Regression Test Suite..."
python3 sim/run_tests.py
