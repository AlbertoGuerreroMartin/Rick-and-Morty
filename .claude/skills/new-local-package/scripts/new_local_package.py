#!/usr/bin/env python3
"""Scaffold a local Swift package and wire it into an Xcode project.

Creates <repo-root>/<Name>/ with a Package.swift whose platform and Swift
language mode are read from the .xcodeproj, then patches project.pbxproj so the
app target actually links the package's library product.

The pbxproj patch is all-or-nothing: the file is backed up first, every edit is
verified afterwards, and any failure restores the backup and falls back to
printing the manual Xcode steps. A half-patched project file is much worse than
an unpatched one, because Xcode may refuse to open it at all.
"""

from __future__ import annotations

import argparse
import os
import random
import re
import shutil
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def find_project(repo_root: Path, explicit: str | None) -> Path:
    if explicit:
        path = Path(explicit)
        if not path.is_absolute():
            path = repo_root / path
        if not path.exists():
            fail(f"no .xcodeproj at {path}")
        return path
    candidates = sorted(repo_root.glob("*/*.xcodeproj")) + sorted(
        repo_root.glob("*.xcodeproj")
    )
    if not candidates:
        fail(f"no .xcodeproj found under {repo_root}; pass --project")
    if len(candidates) > 1:
        names = ", ".join(str(c.relative_to(repo_root)) for c in candidates)
        fail(f"multiple .xcodeproj found ({names}); pass --project")
    return candidates[0]


def swift_tools_version() -> str:
    """Major.minor of the active toolchain, for swift-tools-version."""
    try:
        out = subprocess.run(
            ["swift", "--version"], capture_output=True, text=True, timeout=30
        ).stdout
        match = re.search(r"Swift version (\d+)\.(\d+)", out)
        if match:
            return f"{match.group(1)}.{match.group(2)}"
    except (OSError, subprocess.SubprocessError):
        pass
    return "6.0"


# ---------------------------------------------------------------------------
# Reading settings out of the project
# ---------------------------------------------------------------------------


def target_block(text: str, target: str) -> str | None:
    """The PBXNativeTarget object body for `target`, or None."""
    pattern = re.compile(
        r"([0-9A-F]{24}) /\* " + re.escape(target) + r" \*/ = \{\s*\n"
        r"\s*isa = PBXNativeTarget;.*?\n\t\t\};",
        re.DOTALL,
    )
    match = pattern.search(text)
    return match.group(0) if match else None


def build_setting(text: str, target: str, key: str) -> str | None:
    """Read a build setting, preferring the target's value over the project's.

    Target-level settings win in Xcode, so a project-wide default only matters
    when the target doesn't override it.
    """
    block = target_block(text, target)
    if block:
        config_list = re.search(
            r"buildConfigurationList = ([0-9A-F]{24})", block
        )
        if config_list:
            configs = re.search(
                re.escape(config_list.group(1))
                + r" /\* Build configuration list.*?\*/ = \{.*?buildConfigurations = \((.*?)\);",
                text,
                re.DOTALL,
            )
            if configs:
                for uuid in re.findall(r"([0-9A-F]{24})", configs.group(1)):
                    body = re.search(
                        re.escape(uuid) + r" /\*.*?\*/ = \{(.*?)\n\t\t\};",
                        text,
                        re.DOTALL,
                    )
                    if body:
                        found = re.search(
                            r"\b" + re.escape(key) + r" = ([^;]+);", body.group(1)
                        )
                        if found:
                            return found.group(1).strip().strip('"')
    # Fall back to any value in the file (project-level defaults).
    found = re.search(r"\b" + re.escape(key) + r" = ([^;]+);", text)
    return found.group(1).strip().strip('"') if found else None


def platform_literal(deployment_target: str) -> str:
    """`.iOS(.v18)` for whole majors, `.iOS("18.6")` for point releases.

    SupportedPlatform only has enum cases for major versions, so anything with a
    non-zero minor has to use the string form.
    """
    parts = deployment_target.split(".")
    major = parts[0]
    minor = parts[1] if len(parts) > 1 else "0"
    if minor == "0":
        return f".iOS(.v{major})"
    return f'.iOS("{deployment_target}")'


def language_mode(swift_version: str | None) -> str:
    major = (swift_version or "6").split(".")[0]
    return f".v{major}"


# ---------------------------------------------------------------------------
# Package scaffolding
# ---------------------------------------------------------------------------

GITIGNORE = """\
.DS_Store
/.build
/Packages
xcuserdata/
DerivedData/
.swiftpm/configuration/registries.json
.swiftpm/xcode/package.xcworkspace/contents.xcworkspacedata
.netrc
"""


def package_manifest(name: str, tools: str, platform: str, mode: str) -> str:
    return f"""\
// swift-tools-version: {tools}

import PackageDescription

let package = Package(
    name: "{name}",
    platforms: [
        {platform}
    ],
    products: [
        .library(
            name: "{name}",
            targets: ["{name}"]
        ),
    ],
    targets: [
        .target(
            name: "{name}"
        ),
        .testTarget(
            name: "{name}Tests",
            dependencies: ["{name}"]
        ),
    ],
    swiftLanguageModes: [{mode}]
)
"""


def source_file(name: str) -> str:
    """Entry-point view.

    Named <Name>View rather than <Name> on purpose: a type sharing its module's
    name shadows the module, which breaks qualified lookups like Name.Something.
    Both the type and the initializer are public because the memberwise init is
    internal by default, which would leave the type visible but unusable.
    """
    return f"""\
import SwiftUI

public struct {name}View: View {{
    public init() {{}}

    public var body: some View {{
        Text("{name}")
    }}
}}

#Preview {{
    {name}View()
}}
"""


def test_file(name: str) -> str:
    lower = name[0].lower() + name[1:]
    return f"""\
import Testing
@testable import {name}

@Test func {lower}ViewInitializes() async throws {{
    _ = {name}View()
}}
"""


def scaffold(package_dir: Path, name: str, tools: str, platform: str, mode: str) -> None:
    (package_dir / "Sources" / name).mkdir(parents=True, exist_ok=True)
    (package_dir / "Tests" / f"{name}Tests").mkdir(parents=True, exist_ok=True)
    (package_dir / "Package.swift").write_text(
        package_manifest(name, tools, platform, mode)
    )
    (package_dir / ".gitignore").write_text(GITIGNORE)
    (package_dir / "Sources" / name / f"{name}View.swift").write_text(source_file(name))
    (package_dir / "Tests" / f"{name}Tests" / f"{name}Tests.swift").write_text(
        test_file(name)
    )


# ---------------------------------------------------------------------------
# pbxproj patching
# ---------------------------------------------------------------------------


def new_uuid(text: str) -> str:
    while True:
        uuid = "".join(random.choice("0123456789ABCDEF") for _ in range(24))
        if uuid not in text:
            return uuid


def insert_into_list(text: str, anchor: str, entry: str) -> str:
    """Add `entry` to the parenthesised list that follows `anchor`.

    Handles both the empty `key = (\\n);` form Xcode writes for unused lists and
    a list that already has members.
    """
    index = text.index(anchor)
    open_paren = text.index("(", index)
    close_paren = text.index(");", open_paren)
    body = text[open_paren + 1 : close_paren]
    return text[: open_paren + 1] + body.rstrip() + entry + text[close_paren:]


def patch_project(
    text: str, name: str, relative_path: str, target: str
) -> tuple[str, list[str]]:
    """Return the patched pbxproj text plus a description of each edit.

    Raises ValueError when the project doesn't have the structure we expect, so
    the caller can restore the backup and fall back to manual instructions.
    """
    steps: list[str] = []

    if re.search(r"productName = " + re.escape(name) + r";", text):
        raise ValueError(f"the project already links a package product named {name}")

    block = target_block(text, target)
    if block is None:
        raise ValueError(f"no PBXNativeTarget named {target}")

    # A package folder that was dragged into the navigator leaves a plain
    # PBXFileReference behind. Left in place it becomes a duplicate of the real
    # package once we add the package reference, so drop it first.
    stale = re.search(
        r"\t\t([0-9A-F]{24}) /\* " + re.escape(name) + r" \*/ = \{isa = PBXFileReference;"
        r"[^\n]*path = " + re.escape(relative_path) + r";[^\n]*\};\n",
        text,
    )
    if stale:
        text = text.replace(stale.group(0), "", 1)
        text = re.sub(
            r"\t\t\t\t" + stale.group(1) + r" /\* " + re.escape(name) + r" \*/,\n",
            "",
            text,
        )
        steps.append("removed the stale folder reference left by dragging it in")

    # Locate the target's Frameworks build phase via its buildPhases list, since
    # a target can have several phases and only one links libraries.
    phase_uuids = re.findall(r"([0-9A-F]{24}) /\* \w+ \*/,", block)
    frameworks_uuid = None
    for uuid in phase_uuids:
        body = re.search(
            re.escape(uuid) + r" /\* Frameworks \*/ = \{\s*\n\s*isa = PBXFrameworksBuildPhase;",
            text,
        )
        if body:
            frameworks_uuid = uuid
            break
    if frameworks_uuid is None:
        raise ValueError(f"no PBXFrameworksBuildPhase on target {target}")

    local_ref = new_uuid(text)
    product_dep = new_uuid(text + local_ref)
    build_file = new_uuid(text + local_ref + product_dep)

    # 1. PBXBuildFile entry linking the product.
    entry = (
        f"\t\t{build_file} /* {name} in Frameworks */ = "
        f"{{isa = PBXBuildFile; productRef = {product_dep} /* {name} */; }};\n"
    )
    marker = "/* Begin PBXBuildFile section */\n"
    if marker in text:
        text = text.replace(marker, marker + entry, 1)
    else:
        anchor = "objects = {\n"
        section = (
            "\n/* Begin PBXBuildFile section */\n"
            + entry
            + "/* End PBXBuildFile section */\n"
        )
        text = text.replace(anchor, anchor + section, 1)
    steps.append("added PBXBuildFile for the library product")

    # 2. Reference it from the Frameworks build phase.
    phase_start = text.index(f"{frameworks_uuid} /* Frameworks */ = {{")
    files_anchor = text.index("files = (", phase_start)
    # Slice from the phase's own `files = (` so insert_into_list can't latch on
    # to an earlier build phase that shares the same anchor text.
    text = text[:files_anchor] + insert_into_list(
        text[files_anchor:],
        "files = (",
        f"\n\t\t\t\t{build_file} /* {name} in Frameworks */,\n\t\t\t",
    )
    steps.append(f"linked it from the {target} Frameworks build phase")

    # 3. Declare the product dependency on the target.
    block = target_block(text, target)
    if "packageProductDependencies = (" in block:
        patched_block = insert_into_list(
            block,
            "packageProductDependencies = (",
            f"\n\t\t\t\t{product_dep} /* {name} */,\n\t\t\t",
        )
    else:
        patched_block = block.replace(
            "\t\t\tproductName =",
            f"\t\t\tpackageProductDependencies = (\n"
            f"\t\t\t\t{product_dep} /* {name} */,\n"
            f"\t\t\t);\n\t\t\tproductName =",
            1,
        )
    text = text.replace(block, patched_block, 1)
    steps.append(f"declared the product dependency on target {target}")

    # 4. XCSwiftPackageProductDependency object.
    dep_object = (
        f"\t\t{product_dep} /* {name} */ = {{\n"
        f"\t\t\tisa = XCSwiftPackageProductDependency;\n"
        f"\t\t\tproductName = {name};\n"
        f"\t\t}};\n"
    )
    marker = "/* Begin XCSwiftPackageProductDependency section */\n"
    if marker in text:
        text = text.replace(marker, marker + dep_object, 1)
    else:
        section = (
            "\n/* Begin XCSwiftPackageProductDependency section */\n"
            + dep_object
            + "/* End XCSwiftPackageProductDependency section */\n"
        )
        text = text.replace("\n\t};\n\trootObject", section + "\t};\n\trootObject", 1)
    steps.append("added XCSwiftPackageProductDependency")

    # 5. XCLocalSwiftPackageReference object. Packages outside a synchronized
    #    root group are not auto-discovered, so the project needs this path.
    ref_object = (
        f"\t\t{local_ref} /* XCLocalSwiftPackageReference \"{relative_path}\" */ = {{\n"
        f"\t\t\tisa = XCLocalSwiftPackageReference;\n"
        f"\t\t\trelativePath = {relative_path};\n"
        f"\t\t}};\n"
    )
    marker = "/* Begin XCLocalSwiftPackageReference section */\n"
    if marker in text:
        text = text.replace(marker, marker + ref_object, 1)
    else:
        section = (
            "\n/* Begin XCLocalSwiftPackageReference section */\n"
            + ref_object
            + "/* End XCLocalSwiftPackageReference section */\n"
        )
        successor = "/* Begin XCSwiftPackageProductDependency section */"
        if successor in text:
            text = text.replace(successor, section.lstrip("\n") + "\n" + successor, 1)
        else:
            text = text.replace(
                "\n\t};\n\trootObject", section + "\t};\n\trootObject", 1
            )
    steps.append("added XCLocalSwiftPackageReference")

    # 6. List the reference on the PBXProject object.
    project_match = re.search(
        r"([0-9A-F]{24}) /\* Project object \*/ = \{\s*\n\s*isa = PBXProject;.*?\n\t\t\};",
        text,
        re.DOTALL,
    )
    if project_match is None:
        raise ValueError("no PBXProject object")
    project_block = project_match.group(0)
    entry = f"\n\t\t\t\t{local_ref} /* XCLocalSwiftPackageReference \"{relative_path}\" */,\n\t\t\t"
    if "packageReferences = (" in project_block:
        patched_project = insert_into_list(
            project_block, "packageReferences = (", entry
        )
    else:
        # Xcode keeps these keys alphabetical; slot it in before whichever of
        # these successors exists so the file stays diff-friendly.
        for successor in ("preferredProjectObjectVersion", "productRefGroup", "projectDirPath"):
            token = f"\t\t\t{successor} ="
            if token in project_block:
                patched_project = project_block.replace(
                    token,
                    f"\t\t\tpackageReferences = ({entry});\n{token}",
                    1,
                )
                break
        else:
            raise ValueError("could not find an insertion point for packageReferences")
    text = text.replace(project_block, patched_project, 1)
    steps.append("registered the package reference on the project")

    return text, steps


def verify(path: Path, name: str, relative_path: str) -> None:
    """Confirm the patch produced a parseable project with all six edits."""
    result = subprocess.run(
        ["plutil", "-lint", str(path)], capture_output=True, text=True
    )
    if result.returncode != 0:
        raise ValueError(f"project.pbxproj no longer parses: {result.stdout.strip()}")

    text = path.read_text()
    required = {
        "XCLocalSwiftPackageReference object": "isa = XCLocalSwiftPackageReference;",
        "relative path": f"relativePath = {relative_path};",
        "product dependency object": "isa = XCSwiftPackageProductDependency;",
        "product name": f"productName = {name};",
        "frameworks link": f"{name} in Frameworks",
        "package reference list": "packageReferences = (",
    }
    missing = [label for label, token in required.items() if token not in text]
    if missing:
        raise ValueError("patch incomplete, missing: " + ", ".join(missing))


MANUAL_STEPS = """\
Wire it up in Xcode instead (the package files are correct and already on disk):

  1. File > Add Package Dependencies... > Add Local...
  2. Select {package_dir}
  3. Target {target} > General > Frameworks, Libraries, and Embedded Content > +
  4. Choose the {name} library
"""


# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Scaffold a local Swift package and wire it into an Xcode project."
    )
    parser.add_argument("name", help="Package/module name, UpperCamelCase")
    parser.add_argument("--repo-root", default=".", help="Defaults to the cwd")
    parser.add_argument("--project", help="Path to the .xcodeproj (auto-detected)")
    parser.add_argument("--target", help="App target to link (defaults to project name)")
    parser.add_argument(
        "--no-wire",
        action="store_true",
        help="Only scaffold; leave project.pbxproj untouched",
    )
    parser.add_argument(
        "--wire-only",
        action="store_true",
        help="Wire an existing package into the project without touching its sources",
    )
    parser.add_argument("--dry-run", action="store_true", help="Report the plan only")
    args = parser.parse_args()

    name = args.name
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]*", name):
        fail(f"'{name}' must be UpperCamelCase letters and digits, e.g. Networking")

    repo_root = Path(args.repo_root).resolve()
    project = find_project(repo_root, args.project)
    target = args.target or project.stem
    pbxproj = project / "project.pbxproj"
    if not pbxproj.exists():
        fail(f"no project.pbxproj inside {project}")

    text = pbxproj.read_text()
    deployment = build_setting(text, target, "IPHONEOS_DEPLOYMENT_TARGET")
    if not deployment:
        fail("could not read IPHONEOS_DEPLOYMENT_TARGET; pass --target explicitly")
    swift = build_setting(text, target, "SWIFT_VERSION")
    tools = swift_tools_version()
    platform = platform_literal(deployment)
    mode = language_mode(swift)

    package_dir = repo_root / name
    # The path is stored relative to the .xcodeproj, not the repo root.
    relative_path = os.path.relpath(package_dir, project.parent)

    print(f"package        {name}")
    print(f"location       {package_dir}")
    print(f"project        {project.relative_to(repo_root)} (target {target})")
    print(f"platform       {platform}   <- IPHONEOS_DEPLOYMENT_TARGET {deployment}")
    print(f"language mode  {mode}   <- SWIFT_VERSION {swift or 'unset'}")
    print(f"tools version  {tools}")

    if args.wire_only:
        print("mode           wire-only (existing sources left untouched)")

    if args.dry_run:
        print("\ndry run, nothing written")
        return

    if args.wire_only:
        # Wiring an existing package must never rewrite its sources: the whole
        # point is that the package already holds work worth keeping.
        if not (package_dir / "Package.swift").exists():
            fail(f"--wire-only needs an existing package at {package_dir}")
        print(f"\nusing existing {package_dir.relative_to(repo_root)}/ as-is")
    else:
        if package_dir.exists():
            fail(
                f"{package_dir} already exists"
                " (use --wire-only to link it without regenerating it)"
            )
        scaffold(package_dir, name, tools, platform, mode)
        print(f"\nscaffolded {package_dir.relative_to(repo_root)}/")

    if args.no_wire:
        print(MANUAL_STEPS.format(package_dir=package_dir, target=target, name=name))
        return

    backup = pbxproj.with_suffix(".pbxproj.bak")
    shutil.copy2(pbxproj, backup)
    try:
        patched, steps = patch_project(text, name, relative_path, target)
        pbxproj.write_text(patched)
        verify(pbxproj, name, relative_path)
    except (ValueError, OSError) as error:
        shutil.copy2(backup, pbxproj)
        backup.unlink(missing_ok=True)
        print(f"\ncould not patch the project automatically: {error}", file=sys.stderr)
        print("project.pbxproj restored from backup, unchanged.\n", file=sys.stderr)
        print(
            MANUAL_STEPS.format(package_dir=package_dir, target=target, name=name),
            file=sys.stderr,
        )
        sys.exit(2)

    backup.unlink(missing_ok=True)
    print("wired into the project:")
    for step in steps:
        print(f"  - {step}")
    print(f"\nimport {name} now resolves in the {target} target.")


if __name__ == "__main__":
    main()
