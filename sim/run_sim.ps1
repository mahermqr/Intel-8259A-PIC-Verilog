# PowerShell Script: run_sim.ps1
# Runs Icarus Verilog simulation suite for Intel 8259A PIC

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$ScriptDir\.."

Write-Host "Running Python Regression Test Suite..." -ForegroundColor Cyan
python sim/run_tests.py

if ($LASTEXITCODE -eq 0) {
    Write-Host "All tests completed successfully!" -ForegroundColor Green
} else {
    Write-Host "Simulation failed with errors." -ForegroundColor Red
}
