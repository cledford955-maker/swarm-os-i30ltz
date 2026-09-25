#!/usr/bin/env python3
"""Read-only SHA-256 parity check for a SWARM workspace and its mirror."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
from dataclasses import dataclass
from fnmatch import fnmatch
from pathlib import Path


DEFAULT_EXCLUDES = (
    ".git",
    ".dart_tool",
    ".gradle",
    ".idea",
    ".vscode",
    "__pycache__",
    "build",
    "target",
    "node_modules",
    "20-runtime",
    "30-source/flutter-sdk",
    "10-releases",
    "80-vm",
    "logs",
    "swarm_os_out",
    "swarm_os_work",
    "*.apk",
    "*.iso",
    "*.log",
    "*.pyc",
    "*.qcow2",
    "*.tar",
    "*.tar.*",
    "*.zip",
)


@dataclass(frozen=True)
class Entry:
    kind: str
    sha256: str
    size: int


def _excluded(relative: str, patterns: tuple[str, ...]) -> bool:
    name = relative.rsplit("/", 1)[-1]
    return any(
        relative == pattern
        or relative.startswith(f"{pattern}/")
        or fnmatch(relative, pattern)
        or fnmatch(name, pattern)
        for pattern in patterns
    )


def _hash_file(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
            size += len(chunk)
    return digest.hexdigest(), size


def build_manifest(root: Path, patterns: tuple[str, ...]) -> dict[str, Entry]:
    """Hash regular files and symlink targets without following symlinks."""
    result: dict[str, Entry] = {}
    root = root.resolve()
    for current, dirnames, filenames in os.walk(root, followlinks=False):
        current_path = Path(current)
        relative_dir = current_path.relative_to(root)

        kept_dirs: list[str] = []
        for dirname in sorted(dirnames):
            child = current_path / dirname
            relative = child.relative_to(root).as_posix()
            if _excluded(relative, patterns):
                continue
            if child.is_symlink():
                target = os.readlink(child)
                data = target.encode("utf-8", errors="surrogateescape")
                result[relative] = Entry("symlink", hashlib.sha256(data).hexdigest(), len(data))
                continue
            kept_dirs.append(dirname)
        dirnames[:] = kept_dirs

        for filename in sorted(filenames):
            path = current_path / filename
            relative = (relative_dir / filename).as_posix()
            if _excluded(relative, patterns):
                continue
            try:
                if path.is_symlink():
                    target = os.readlink(path)
                    data = target.encode("utf-8", errors="surrogateescape")
                    result[relative] = Entry("symlink", hashlib.sha256(data).hexdigest(), len(data))
                elif path.is_file():
                    digest, size = _hash_file(path)
                    result[relative] = Entry("file", digest, size)
            except (FileNotFoundError, PermissionError) as error:
                raise RuntimeError(f"cannot hash {relative}: {error}") from error
    return result


def compare(source: dict[str, Entry], mirror: dict[str, Entry]) -> dict[str, object]:
    source_paths = set(source)
    mirror_paths = set(mirror)
    common = source_paths & mirror_paths
    changed = sorted(path for path in common if source[path] != mirror[path])
    only_source = sorted(source_paths - mirror_paths)
    only_mirror = sorted(mirror_paths - source_paths)
    return {
        "in_sync": not (changed or only_source or only_mirror),
        "source_entries": len(source),
        "mirror_entries": len(mirror),
        "changed": changed,
        "only_source": only_source,
        "only_mirror": only_mirror,
    }


def _atomic_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _manifest_text(entries: dict[str, Entry]) -> str:
    return "".join(
        f"{entry.sha256}  {path}\n" for path, entry in sorted(entries.items())
    )


def _inside(child: Path, parent: Path) -> bool:
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--mirror", type=Path, required=True)
    parser.add_argument("--manifest-dir", type=Path)
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--skip-missing", action="store_true")
    parser.add_argument(
        "--require-mounts",
        action="store_true",
        help="treat roots that are not active mountpoints as unavailable",
    )
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    source = args.source.resolve()
    mirror = args.mirror.resolve()
    if source == mirror:
        print("source and mirror must be different directories", file=sys.stderr)
        return 2

    missing = [str(path) for path in (source, mirror) if not path.is_dir()]
    if missing:
        report = {"status": "skipped" if args.skip_missing else "error", "missing": missing}
        print(json.dumps(report, sort_keys=True) if args.json else f"{report['status']}: missing {', '.join(missing)}")
        return 0 if args.skip_missing else 2
    if args.require_mounts:
        unmounted = [str(path) for path in (source, mirror) if not path.is_mount()]
        if unmounted:
            report = {
                "status": "skipped" if args.skip_missing else "error",
                "unmounted": unmounted,
            }
            print(
                json.dumps(report, sort_keys=True)
                if args.json
                else f"{report['status']}: unmounted {', '.join(unmounted)}"
            )
            return 0 if args.skip_missing else 2

    if args.manifest_dir and (
        _inside(args.manifest_dir, source) or _inside(args.manifest_dir, mirror)
    ):
        print("manifest directory must be outside both compared trees", file=sys.stderr)
        return 2

    patterns = tuple(dict.fromkeys((*DEFAULT_EXCLUDES, *args.exclude)))
    try:
        source_manifest = build_manifest(source, patterns)
        mirror_manifest = build_manifest(mirror, patterns)
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    report = {
        "status": "in_sync",
        "source": str(source),
        "mirror": str(mirror),
        "excluded_patterns": list(patterns),
        **compare(source_manifest, mirror_manifest),
    }
    if not report["in_sync"]:
        report["status"] = "drift"

    if args.manifest_dir:
        output = args.manifest_dir.resolve()
        _atomic_text(output / "source.sha256", _manifest_text(source_manifest))
        _atomic_text(output / "mirror.sha256", _manifest_text(mirror_manifest))
        _atomic_text(output / "report.json", json.dumps(report, indent=2, sort_keys=True) + "\n")

    if args.json:
        print(json.dumps(report, sort_keys=True))
    else:
        print(
            f"{report['status']}: source={report['source_entries']} "
            f"mirror={report['mirror_entries']} changed={len(report['changed'])} "
            f"only_source={len(report['only_source'])} only_mirror={len(report['only_mirror'])}"
        )
        for category in ("changed", "only_source", "only_mirror"):
            for path in report[category]:
                print(f"{category}: {path}")
    return 0 if report["in_sync"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
