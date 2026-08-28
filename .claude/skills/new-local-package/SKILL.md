---
name: new-local-package
description: Scaffold a new local Swift package (feature module, library, or framework) and wire it into the Xcode project so the app target can import it. Use this skill whenever the user wants to add a new module, package, feature module, or library to this iOS project — including phrasings like "create a Networking package", "add a DesignSystem module", "split this out into its own package", "I need a new local package for X", or "modularize this". Also use it when a package exists on disk but `import <Module>` doesn't resolve, since that means the project wiring is missing.
---

# Creating a local Swift package

Local packages are how this project is modularized. Getting one working means
two separate things have to be true: the package has to exist on disk with a
manifest that matches the app's platform and language mode, **and** the
`.xcodeproj` has to reference it and link its library product to the app target.
Creating the folder alone does nothing — Xcode has no idea it exists, and
`import <Module>` fails with "No such module".

`scripts/new_local_package.py` does both.

## Usage

From the repo root:

```bash
python3 .claude/skills/new-local-package/scripts/new_local_package.py Networking
```

Add `--dry-run` first if you want to see the detected settings without writing
anything. Other flags: `--no-wire` (scaffold only), `--target <name>` (link a
target other than the app), `--project <path>` (when auto-detection is ambiguous).

The name must be UpperCamelCase — it becomes the directory, the package, the
library product, and the module name all at once.

## When the package already exists

If a package is on disk but `import <Module>` fails, the sources are usually
fine and only the project wiring is missing. Wire it up without regenerating
anything:

```bash
python3 .claude/skills/new-local-package/scripts/new_local_package.py Characters --wire-only
```

This makes the same six project edits and leaves every file in the package
alone. It also removes the stale `PBXFileReference` that dragging a folder into
the navigator leaves behind, which would otherwise show up as a duplicate.

Reach for this rather than deleting and re-scaffolding. Re-creating the package
would throw away whatever the user has written in it, and the missing piece was
never the package to begin with.

## Conventions this project uses

**Packages live at the repo root**, as siblings of `RickMorty/`. The script
places them there and writes a `relativePath = ../<Name>` reference. Don't move a
package under `RickMorty/RickMorty/` — that directory is a
`PBXFileSystemSynchronizedRootGroup`, and packages inside it get wired by a
completely different mechanism (`membershipExceptions`, no package reference),
which is why the two existing packages in this repo are inconsistent with each
other. New ones go at the root.

**Platform and language mode are read from the project, never hardcoded.** The
script reads `IPHONEOS_DEPLOYMENT_TARGET` and `SWIFT_VERSION` off the app target
and writes matching values into `Package.swift`. This matters because a package
whose `platforms:` is lower than the app's silently loses access to newer API,
and a package on a different `swiftLanguageModes` gets different concurrency
diagnostics than the app — mismatches that surface later as confusing errors at
the module boundary. Whole majors become `.iOS(.v18)`; point releases like 18.6
become `.iOS("18.6")`, because `SupportedPlatform` only has enum cases for
majors.

**Everything the app touches must be `public`, including the initializer.** This
is the one that actually breaks builds, and Xcode's package template gets it
wrong: the template's type is `internal`. From the app, an internal type isn't
visible at all, so the name falls through to the *module* and you get the
genuinely baffling `cannot call value of non-function type 'module<Episodes>'`.
Making it `public` is necessary but not sufficient — a `public struct` still has
an **internal** memberwise initializer, so it also needs an explicit
`public init() {}` or it's visible-but-not-constructible.

**Name the entry type `<Name>View` (or `<Name>Client`, etc.), not `<Name>`.**
Unlike the access-level rule, this one is a convention rather than a
build-breaker: a *public* type sharing its module's name does compile and
`Characters()` resolves to the type. It's still worth avoiding, because the
collision makes qualified lookups ambiguous — `Characters.SomeNestedType` and
`import struct Characters.Characters` both get confusing — and it misleads
anyone reading the call site about whether they're naming a module or a type.

Pick the suffix from what the module actually is. A SwiftUI feature module gets
`<Name>View`; a networking module is better served by something like
`APIClient`. Don't force a `View` on a module that isn't one just because the
scaffold generated one — replace the placeholder with whatever the module's real
entry point should be, keeping it `public` with a `public` init.

## Stay inside the package you were asked for

Touch the new package and `project.pbxproj`, and nothing else. Existing packages
in this repo have their own pre-existing problems — internal entry types, two
different placement conventions, a package that was never wired up. Those are
real, and worth *mentioning* if you trip over one, but fixing them changes other
modules' public API and is a separate decision the user should make deliberately.
Report what you noticed; don't go fix it unasked.

## What gets created

```
<Name>/
├── .gitignore                              SPM-standard, keeps the package portable
├── Package.swift                           detected platform + language mode
├── Sources/<Name>/<Name>View.swift         public struct <Name>View, public init
└── Tests/<Name>Tests/<Name>Tests.swift     Swift Testing (@Test), matches the repo style
```

## What gets changed in project.pbxproj

Six edits, all of which Xcode would make itself via **File → Add Package
Dependencies… → Add Local…** plus the target's Frameworks list:

1. `XCLocalSwiftPackageReference` object holding `relativePath = ../<Name>`
2. That reference listed in the `PBXProject`'s `packageReferences`
3. `XCSwiftPackageProductDependency` object naming the library product
4. That dependency listed in the target's `packageProductDependencies`
5. `PBXBuildFile` entry carrying the `productRef`
6. That build file listed in the target's Frameworks build phase

Steps 1–2 register the package with the *project*; steps 3–6 link the *product*
to a *target*. Both halves are required — a package that's registered but not
linked resolves in the package graph yet still won't import.

The script backs up `project.pbxproj`, verifies afterwards that the file still
parses (`plutil -lint`) and that all six edits are present, and restores the
backup and prints the manual Xcode steps if anything is off. A half-patched
project file is worse than an unpatched one, since Xcode may refuse to open it
at all. If the script exits with status 2, the package on disk is still correct
— only the wiring needs doing by hand.

## Verifying it worked

Confirm the project sees the package. The `@ local` marker is the thing to look
for:

```bash
xcodebuild -list -project RickMorty/RickMorty.xcodeproj
```

Then build the package itself:

```bash
xcodebuild -project RickMorty/RickMorty.xcodeproj -scheme <Name> -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

**Don't verify with `swift build` or `swift test`.** Those target the host
machine, and an iOS-only package (`platforms: [.iOS(...)]`) fails on macOS with
misleading availability errors like "conformance of 'Text' to 'View' is only
available in macOS 10.15 or newer". Nothing is wrong with the package; you just
built it for the wrong platform. Always go through `xcodebuild` with an iOS
destination, or add `.macOS(...)` to `platforms:` if you genuinely want it to
build both ways.

If Xcode is open while the script runs, the project file changes underneath it.
Xcode usually picks this up on its own; if the package doesn't appear in the
navigator, close and reopen the project.

## Adding a dependency between packages

Local packages depend on each other through the manifest, not the project file.
In the dependent package's `Package.swift`:

```swift
dependencies: [
    .package(path: "../Networking"),
],
targets: [
    .target(
        name: "Characters",
        dependencies: [.product(name: "Networking", package: "Networking")]
    ),
]
```

No `.xcodeproj` change is needed for this — the app only links the top-level
products it uses directly, and SPM resolves the rest of the graph.
