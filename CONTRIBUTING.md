# Contributing

Thanks for helping improve swift-solana-kit. Keep changes small, clear and easy to review.

## Build And Test

Use the SwiftPM commands from the repository root:

```sh
swift build
swift test
```

When a change is limited to one target, prefer the narrower checks:

```sh
swift build --target <TargetName>
swift test --filter <TargetName>Tests
```

## Public API

Every public symbol must appear in `PublicAPI/<TargetName>.swift`.

If your change needs a new public symbol, update the matching contract file as part of the API review. Public API needs tests. Public API comments should explain behavior, failure modes and important constraints.

## Formatting

Until a repository formatter configuration is committed, match local style.

After a formatter configuration lands, use:

```sh
swift format lint --recursive Sources Tests
```

Do not hide broad formatting changes inside behavior changes.

## CI Gates

Every pull request to `master` and every push to `master` runs the reusable SwiftPM gate workflow. It validates the package manifest, builds the root package, builds the iOS simulator target, runs the test suite, dumps the public symbol graph, checks `PublicAPI/` target coverage and audits the Git release archive for local-only files.

Release tags run the same SwiftPM gates before a GitHub release is created. Do not tag a release until the target commit is already green on CI.

## Tests

Tests live under `Tests/<TargetName>Tests/`.

Add or update tests for new behavior, bug fixes and new public surface. Keep tests deterministic. Do not require live Solana RPC access for package tests.

## Commit Style

Use concise imperative commit subjects.

- Target length under 60 characters.
- Hard cap of 72 characters.
- Optional body under 500 characters.
- No em dashes.
- No Oxford commas.
- No internal planning labels.
- No release-plan wording.

The subject should describe the behavior shipped.

## Security

Follow [SECURITY.md](SECURITY.md) for vulnerability reports. Do not disclose vulnerabilities in public issues or pull requests.

## License Grant

By contributing, you agree that your contribution is licensed under the Apache License 2.0.
