#!/usr/bin/env python3
"""CG grader for the LoongArch myCPU BRAM trace verification.

Default runtime paths:
  workspace: /opt/cpu-judge
  test data: /coursegrader/testdata
  submission: /coursegrader/submit

Only the final JSON result is written to stdout. Build and simulation logs are
captured and included in the result's detail field.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile


DEFAULT_BASE = "/opt/cpu-judge"
DEFAULT_TESTDATA = "/coursegrader/testdata"
DEFAULT_SUBMIT = "/coursegrader/submit"

PROJECT_REL = os.path.join("cdp_ede_local-master", "mycpu_env")
SOURCE_SUFFIXES = {".v", ".sv", ".vh", ".svh"}
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


def emit(verdict, score, comment, detail=""):
    detail = ANSI_RE.sub("", detail or "")
    detail = detail.replace("\x00", "")
    if len(detail) > 8000:
        detail = detail[-8000:]

    print(json.dumps({
        "verdict": verdict,
        "score": int(score),
        "comment": comment,
        "detail": detail,
    }, ensure_ascii=False))


def parse_args():
    parser = argparse.ArgumentParser(description="myCPU BRAM CG grader")
    parser.add_argument("--base", default=os.environ.get("CPU_JUDGE_BASE", DEFAULT_BASE))
    parser.add_argument(
        "--testdata",
        default=os.environ.get("CPU_JUDGE_TESTDATA", DEFAULT_TESTDATA),
    )
    parser.add_argument(
        "--submit",
        default=os.environ.get("CPU_JUDGE_SUBMIT", DEFAULT_SUBMIT),
    )
    parser.add_argument(
        "--make-target",
        default=os.environ.get("CPU_JUDGE_MAKE_TARGET", ""),
        help="Optional make target; defaults to the Makefile's first target.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=int(os.environ.get("CPU_JUDGE_TIMEOUT", "300")),
        help="Build and simulation timeout in seconds.",
    )
    return parser.parse_args()


def merge_tree(src, dst):
    """Recursively copy the contents of src into dst on Python 3.6."""
    if not os.path.isdir(src):
        raise RuntimeError("missing directory: {}".format(src))

    if not os.path.isdir(dst):
        os.makedirs(dst)

    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        out_dir = dst if rel == "." else os.path.join(dst, rel)
        if not os.path.isdir(out_dir):
            os.makedirs(out_dir)

        for name in files:
            shutil.copy2(os.path.join(root, name), os.path.join(out_dir, name))


def safe_extract_zip(zip_path, destination):
    destination_real = os.path.realpath(destination)

    with zipfile.ZipFile(zip_path, "r") as archive:
        for info in archive.infolist():
            target = os.path.realpath(os.path.join(destination_real, info.filename))
            if os.path.commonpath([destination_real, target]) != destination_real:
                raise RuntimeError("unsafe path in zip: {}".format(info.filename))

            file_type = (info.external_attr >> 16) & 0o170000
            if file_type == 0o120000:
                raise RuntimeError("symbolic link in zip: {}".format(info.filename))

        archive.extractall(destination)


def find_cpu_root(base):
    candidates = []
    for root, dirs, files in os.walk(base):
        dirs[:] = [name for name in dirs if name not in (".git", "__MACOSX")]
        if "mycpu_top.v" in files:
            candidates.append(root)

    if not candidates:
        return None

    candidates.sort(key=lambda path: (
        os.path.basename(path) != "myCPU",
        len(os.path.realpath(path).split(os.sep)),
    ))
    return candidates[0]


def materialize_submission(submit_dir):
    cpu_root = find_cpu_root(submit_dir)
    if cpu_root is not None:
        return cpu_root

    zip_files = []
    for root, dirs, files in os.walk(submit_dir):
        for name in files:
            if name.lower().endswith(".zip"):
                zip_files.append(os.path.join(root, name))

    if not zip_files:
        raise RuntimeError("submission does not contain a .zip or mycpu_top.v")

    extract_dir = tempfile.mkdtemp(prefix="mycpu-submit-")
    for zip_path in sorted(zip_files):
        safe_extract_zip(zip_path, extract_dir)

    cpu_root = find_cpu_root(extract_dir)
    if cpu_root is None:
        raise RuntimeError("no mycpu_top.v found after extracting submission")
    return cpu_root


def clear_old_cpu_sources(cpu_dir):
    for root, dirs, files in os.walk(cpu_dir):
        for name in files:
            if os.path.splitext(name)[1].lower() in SOURCE_SUFFIXES:
                os.unlink(os.path.join(root, name))


def copy_student_sources(src_root, cpu_dir):
    copied = 0
    for root, dirs, files in os.walk(src_root):
        rel = os.path.relpath(root, src_root)
        out_dir = cpu_dir if rel == "." else os.path.join(cpu_dir, rel)

        for name in files:
            if os.path.splitext(name)[1].lower() not in SOURCE_SUFFIXES:
                continue

            src = os.path.join(root, name)
            if os.path.islink(src) or not os.path.isfile(src):
                continue

            if not os.path.isdir(out_dir):
                os.makedirs(out_dir)
            shutil.copy2(src, os.path.join(out_dir, name))
            copied += 1

    if copied == 0:
        raise RuntimeError("submission contains no Verilog source files")


def run_make(base_dir, make_dir, target, timeout):
    command = ["make", "-B", "-C", make_dir]
    if target:
        command.append(target)

    try:
        process = subprocess.run(
            command,
            cwd=base_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
        output = process.stdout.decode("utf-8", errors="replace")
        return process.returncode, output, False
    except subprocess.TimeoutExpired as exc:
        output = exc.output or b""
        if not isinstance(output, bytes):
            output = str(output).encode("utf-8", errors="replace")
        return None, output.decode("utf-8", errors="replace"), True


def determine_result(returncode, output, timed_out):
    if "Fail!!!Total" in output or "Error!!!" in output:
        return "WA", 0, "golden trace 不一致或功能测试点失败"

    if timed_out:
        return "TLE", 0, "编译或仿真超时"

    if "Test end!" in output and "----PASS!!!" in output:
        return "AC", 100, "全部 golden trace 比较通过"

    lowered = output.lower()
    if returncode != 0 and (
        "syntax error" in lowered
        or "error:" in lowered
        or "unknown module type" in lowered
    ):
        return "CE", 0, "Verilog 编译失败"

    if returncode != 0:
        return "RE", 0, "Makefile 或仿真异常退出"

    return "RE", 0, "仿真退出但没有产生最终 PASS 标记"


def grade(args):
    base_dir = os.path.realpath(args.base)
    testdata_dir = os.path.realpath(args.testdata)
    submit_dir = os.path.realpath(args.submit)

    if not os.path.isdir(base_dir):
        raise RuntimeError("workspace does not exist: {}".format(base_dir))
    if not os.path.isdir(testdata_dir):
        raise RuntimeError("testdata does not exist: {}".format(testdata_dir))
    if not os.path.isdir(submit_dir):
        raise RuntimeError("submission directory does not exist: {}".format(submit_dir))

    os.chdir(base_dir)

    mycpu_env = os.path.join(base_dir, PROJECT_REL)
    cpu_dir = os.path.join(mycpu_env, "myCPU")
    gettrace_dir = os.path.join(mycpu_env, "gettrace")
    func_dir = os.path.join(mycpu_env, "func")
    testbench_dir = os.path.join(
        mycpu_env, "soc_verify", "soc_bram", "testbench"
    )

    if not os.path.isdir(cpu_dir):
        raise RuntimeError("workspace missing myCPU directory: {}".format(cpu_dir))

    merge_tree(os.path.join(testdata_dir, "gettrace"), gettrace_dir)
    merge_tree(os.path.join(testdata_dir, "func"), func_dir)

    student_root = materialize_submission(submit_dir)
    clear_old_cpu_sources(cpu_dir)
    copy_student_sources(student_root, cpu_dir)

    cpu_makefile = os.path.join(cpu_dir, "Makefile")
    testbench_makefile = os.path.join(testbench_dir, "Makefile")

    if os.path.isfile(cpu_makefile):
        make_dir = cpu_dir
        target = args.make_target
    elif os.path.isfile(testbench_makefile):
        make_dir = testbench_dir
        target = args.make_target or "iverilog"
    else:
        raise RuntimeError("neither myCPU/Makefile nor testbench/Makefile exists")

    returncode, output, timed_out = run_make(
        base_dir,
        make_dir,
        target,
        args.timeout,
    )
    verdict, score, comment = determine_result(returncode, output, timed_out)

    if comment.startswith("Verilog 编译失败"):
        verdict = "CE"
    elif comment == "Makefile 或仿真异常退出" and returncode == 2:
        verdict = "CE"

    return verdict, score, comment, output


def main():
    args = parse_args()
    try:
        verdict, score, comment, output = grade(args)
        emit(verdict, score, comment, output)
    except Exception as exc:
        emit("RE", 0, "评测内核异常", "{}: {}".format(type(exc).__name__, exc))


if __name__ == "__main__":
    main()
