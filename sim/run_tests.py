#!/usr/bin/env python3
# ============================================================================
# Script: run_tests.py
# Description: Automated test runner and regression suite for Intel 8259A PIC.
# ============================================================================

import os
import sys
import subprocess
import glob

def main():
    repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_dir)

    iverilog = "iverilog"
    vvp = "vvp"

    # Find iverilog on Windows if not in default PATH
    if sys.platform.startswith("win"):
        candidate_paths = [
            "C:/iverilog/bin/iverilog.exe",
            "C:/Program Files/iverilog/bin/iverilog.exe",
            "C:/Program Files (x86)/iverilog/bin/iverilog.exe"
        ]
        for cp in candidate_paths:
            if os.path.exists(cp):
                iverilog = cp
                vvp = os.path.join(os.path.dirname(cp), "vvp.exe")
                break

    rtl_files = glob.glob("rtl/*.v")
    tb_files = sorted(glob.glob("tb/*.v"))

    print("=" * 65)
    print("      Intel 8259A PIC - Automated Regression Test Suite")
    print("=" * 65)
    print(f"RTL Modules ({len(rtl_files)}): {[os.path.basename(f) for f in rtl_files]}")
    print(f"Testbenches ({len(tb_files)}): {[os.path.basename(f) for f in tb_files]}")
    print("-" * 65)

    passed_count = 0
    failed_count = 0

    for tb in tb_files:
        tb_name = os.path.splitext(os.path.basename(tb))[0]
        vvp_file = f"sim/{tb_name}.vvp"

        # Determine required source files
        if "single" in tb_name or "cascade" in tb_name:
            sources = rtl_files + [tb]
        else:
            # Match module name
            module_name = tb_name.replace("tb_", "")
            matched_rtl = [f for f in rtl_files if module_name.lower() in f.lower()]
            sources = matched_rtl + [tb] if matched_rtl else rtl_files + [tb]

        # Compile
        cmd_comp = [iverilog, "-g2005", "-s", tb_name, "-o", vvp_file] + sources
        comp_res = subprocess.run(cmd_comp, capture_output=True, text=True)

        if comp_res.returncode != 0:
            print(f"[{'FAIL':^6}] {tb_name:<30} Compilation Error")
            print(comp_res.stderr)
            failed_count += 1
            continue

        # Simulate
        sim_res = subprocess.run([vvp, vvp_file], capture_output=True, text=True)
        out = sim_res.stdout

        if "ALL TESTS PASSED" in out or "PASSED" in out:
            print(f"[{'PASS':^6}] {tb_name:<30} Verified Cleanly")
            passed_count += 1
        else:
            print(f"[{'FAIL':^6}] {tb_name:<30} Test Assertion Failure")
            print(out)
            failed_count += 1

    print("=" * 65)
    print(f"Test Summary: Total={len(tb_files)} | Passed={passed_count} | Failed={failed_count}")
    print("=" * 65)

    sys.exit(0 if failed_count == 0 else 1)

if __name__ == "__main__":
    main()
