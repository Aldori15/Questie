"""Run Lua and Python regressions locally or with CI's required toolchain.

Set QUESTIE_TEST_LUA to the Lua 5.2 executable on Windows. Optional tools use
QUESTIE_TEST_LUA51, QUESTIE_TEST_LUAC (5.1), and QUESTIE_TEST_LUAC52. The --ci
mode requires all four tools; local runs explicitly report unavailable checks.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
TOOL_SPECS = {
    "lua": ("QUESTIE_TEST_LUA", ("lua5.2", "lua52", "lua")),
    "lua51": ("QUESTIE_TEST_LUA51", ("lua5.1",)),
    "luac": ("QUESTIE_TEST_LUAC", ("luac5.1",)),
    "luac52": ("QUESTIE_TEST_LUAC52", ("luac5.2",)),
}
OPTIONAL_CHECKS = {
    "lua51": "Lua 5.1-compatible suites",
    "luac": "addon Lua 5.1 syntax",
    "luac52": "Lua regression test syntax",
}


def resolve_tools(environment, strict):
    tools = {}
    for name, (variable, candidates) in TOOL_SPECS.items():
        configured = environment.get(variable)
        if configured:
            tools[name] = shutil.which(configured)
            if tools[name] is None:
                raise ValueError(f"{variable} executable was not found: {configured}")
        else:
            tools[name] = next((path for candidate in candidates
                                if (path := shutil.which(candidate))), None)
    missing = [name for name, path in tools.items() if path is None and (strict or name == "lua")]
    if missing:
        variables = ", ".join(TOOL_SPECS[name][0] for name in missing)
        raise ValueError(f"Required regression tools unavailable; install them or set {variables}")
    return tools


def run(command, environment, label):
    print(f"Running {label}", flush=True)
    result = subprocess.run(command, cwd=ROOT, env=environment)
    if result.returncode:
        raise subprocess.CalledProcessError(result.returncode, command)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ci", action="store_true", help="Require every CI interpreter/compiler")
    args = parser.parse_args(argv)
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", PYTHONNOUSERSITE="1")
    try:
        # Resolve every required tool before starting any test or syntax check.
        tools = resolve_tools(environment, args.ci)
        tests = sorted(ROOT.glob("tools/tests/test_*.lua"))
        if not tests:
            raise ValueError("No Lua regression suites found")
        environment["QUESTIE_TEST_LUA"] = tools["lua"]
        if tools["luac"]:
            environment["QUESTIE_TEST_LUAC"] = tools["luac"]
        skipped = [label for name, label in OPTIONAL_CHECKS.items() if not tools[name]]
        for label in skipped:
            print(f"SKIPPED: {label}; optional tool unavailable locally", flush=True)
        if tools["luac"]:
            run([sys.executable, "-B", "tools/check_lua_syntax.py", "--luac", tools["luac"]],
                environment, "addon Lua 5.1 syntax")
        if tools["luac52"]:
            for test in tests:
                run([tools["luac52"], "-p", str(test)], environment, f"syntax: {test.name}")
        if tools["lua51"]:
            for test in tests:
                with test.open(encoding="utf-8-sig") as stream:
                    header = stream.readline()
                if "Lua 5.1" in header:
                    run([tools["lua51"], str(test)], environment, f"{test.name} (Lua 5.1)")
        for test in tests:
            run([tools["lua"], str(test)], environment, test.name)
        run([sys.executable, "-B", "-m", "unittest", "discover", "-s", "tools/tests",
             "-p", "test_*.py", "-v"], environment, "Python regression suites")
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as error:
        print(f"FAILED: {' '.join(map(str, error.cmd))} (exit {error.returncode})", file=sys.stderr)
        return error.returncode
    if skipped:
        print("Available regression checks passed; optional checks listed above remain unverified.")
    else:
        print("All CI regression checks passed." if args.ci else "All regression checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
