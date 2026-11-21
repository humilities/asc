#!/usr/bin/env python3
"""Check run_hpcg.sh output and generate day4-runs.csv.

Usage: python3 day4_check.py OUT_ROOT [--output CSV]
"""

import argparse
import csv
import re
from pathlib import Path


FIELDS = ["run_id", "nx", "ny", "nz", "ranks", "threads", "npx", "npy", "npz",
          "global_dims", "seconds_requested", "total_time_s", "gflops_rating",
          "spmv_time_s", "mg_time_s", "valid", "official", "swap_status", "exit_code", "notes"]
PASS_KEYS = ["Spectral Convergence Tests::Result",
             "Departure from Symmetry |x'Ay-y'Ax|/(2*||x||*||A||*||y||)/epsilon::Result",
             "Iteration Count Information::Result", "Reproducibility Information::Result"]
NUMERIC = re.compile(r"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$")


def kv(path):
    if not path.is_file():
        return {}
    result = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def parameter_kv(path):
    if not path.is_file():
        return {}
    content = path.read_text(encoding="utf-8", errors="replace")
    return dict(re.findall(r"(?:^|\s)([A-Za-z_][A-Za-z_0-9]*)=([^\s]+)", content))


def check(directory):
    row = dict.fromkeys(FIELDS, "")
    row.update(run_id=directory.name, official="NO", swap_status="UNVERIFIED")
    issues = []
    params = parameter_kv(directory / "parameters.txt")
    if not params:
        issues.append("missing_parameters")
    for field, key in [("nx", "NX"), ("ny", "NY"), ("nz", "NZ"),
                       ("ranks", "RANKS"), ("threads", "THREADS"),
                       ("seconds_requested", "SECONDS"), ("exit_code", "exit_code")]:
        row[field] = params.get(key, "")
    if row["exit_code"] != "0":
        issues.append("exit_code_not_0")
    for name in ["hpcg.dat", "stdout.log", "stderr.log"]:
        if not (directory / name).is_file():
            issues.append("missing_" + name)

    reports = sorted(directory.glob("HPCG-Benchmark_*.txt"))
    if len(reports) != 1:
        issues.append("report_count_" + str(len(reports)))
    if not reports:
        row["valid"] = "CHECK"
        row["notes"] = ";".join(issues + ["swap_not_proven"])
        return row
    report = kv(reports[0]) if reports else {}
    for field, key in [("npx", "Processor Dimensions::npx"),
                       ("npy", "Processor Dimensions::npy"),
                       ("npz", "Processor Dimensions::npz"),
                       ("total_time_s", "Benchmark Time Summary::Total"),
                       ("spmv_time_s", "Benchmark Time Summary::SpMV"),
                       ("mg_time_s", "Benchmark Time Summary::MG"),
                       ("gflops_rating", "Final Summary::HPCG result is VALID with a GFLOP/s rating of")]:
        row[field] = report.get(key, "")
        if not row[field]:
            issues.append("missing_" + field)
    dims = [report.get("Global Problem Dimensions::Global n" + axis, "") for axis in "xyz"]
    row["global_dims"] = "x".join(dims) if all(dims) else ""
    if not row["global_dims"]:
        issues.append("missing_global_dims")

    for field, key in [("nx", "Local Domain Dimensions::nx"),
                       ("ny", "Local Domain Dimensions::ny"),
                       ("nz", "Local Domain Dimensions::nz"),
                       ("ranks", "Machine Summary::Distributed Processes"),
                       ("threads", "Machine Summary::Threads per processes")]:
        if row[field] != report.get(key, ""):
            issues.append(field + "_mismatch")
    if all(row[field].isdigit() for field in ["npx", "npy", "npz", "ranks"]):
        if int(row["npx"]) * int(row["npy"]) * int(row["npz"]) != int(row["ranks"]):
            issues.append("processor_grid_mismatch")
    else:
        issues.append("processor_grid_unverified")
    for key in PASS_KEYS:
        if report.get(key) != "PASSED":
            issues.append("validation_not_passed:" + key)
    for field in ["gflops_rating", "total_time_s", "spmv_time_s", "mg_time_s"]:
        if not NUMERIC.fullmatch(row[field]):
            issues.append(field + "_not_numeric")
    if NUMERIC.fullmatch(row["total_time_s"]) and row["seconds_requested"].isdigit():
        if float(row["total_time_s"]) < 0.9 * int(row["seconds_requested"]):
            issues.append("reported_time_below_requested_review")
    stderr = directory / "stderr.log"
    if stderr.is_file() and re.search(r"out of memory|oom|killed process|cannot allocate memory",
                                      stderr.read_text(encoding="utf-8", errors="replace"), re.I):
        issues.append("possible_oom_in_stderr")

    advisory = {"reported_time_below_requested_review"}
    row["valid"] = "VALID" if not [issue for issue in issues if issue not in advisory] else "CHECK"
    notes = list(issues)
    if row["seconds_requested"].isdigit() and int(row["seconds_requested"]) < 1800:
        notes.append("exploratory_short_run")
    notes.append("swap_not_proven")
    row["notes"] = ";".join(notes)
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out_root", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.out_root.expanduser().resolve()
    if not root.is_dir():
        parser.error("Directory not found: " + str(root))
    directories = sorted(path for path in root.glob("HPCG_*") if path.is_dir())
    if not directories:
        parser.error("No HPCG_* directories in " + str(root))
    output = (args.output or root / "day4-runs.csv").expanduser().resolve()
    rows = [check(path) for path in directories]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    for row in rows:
        print(f"{row['run_id']}: {row['valid']}, {row['gflops_rating'] or '-'} GFLOP/s, {row['notes']}")
    print("CSV:", output)
    print("swap_status=UNVERIFIED: HPCG reports cannot prove that swap was unused.")
    return 0 if all(row["valid"] == "VALID" for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
