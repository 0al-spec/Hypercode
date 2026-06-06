# Hypercode — Release & Distribution Roadmap

How the two shipped artifacts get released: the Swift `hypercode` CLI/library and
the VS Code extension that drives it. The extension is a thin LSP client — it
needs the CLI on `PATH` — so the two ship together.

## Artifacts

| Artifact | Source | Consumed as |
|---|---|---|
| `hypercode` CLI + `Hypercode` library | root SwiftPM package | `swift build`, or `.package(url: …, from: …)` |
| Hypercode VS Code extension | `editors/vscode/` | `.vsix`, or the VS Code Marketplace |

## VS Code extension

The extension (`publisher: 0al-spec`, id `hypercode`) is a thin
`vscode-languageclient` that spawns `hypercode lsp`. Three release tiers, from
local to public.

### Tier 1 — VSIX (local install / GitHub Release asset)

No account required. Produces a portable `.vsix` anyone can install.

```bash
cd editors/vscode
npm install
npm install -g @vscode/vsce      # one-time
vsce package                     # → hypercode-<version>.vsix
```

Install it:

```bash
code --install-extension hypercode-<version>.vsix
```

The `.vsix` can be attached to a GitHub Release as a download.

> Note: `.vscodeignore` intentionally does **not** exclude `node_modules` —
> `vsce` resolves production vs dev dependencies itself, and excluding the folder
> would strip `vscode-languageclient` from the package.

### Tier 2 — VS Code Marketplace (public)

1. **Create the publisher** `0al-spec` at
   <https://marketplace.visualstudio.com/manage> (must match `package.json`'s
   `publisher`).
2. **Mint an Azure DevOps PAT** at <https://dev.azure.com> →
   User Settings → Personal access tokens, scope **Marketplace → Manage**.
3. **Publish:**

   ```bash
   vsce login 0al-spec     # paste the PAT
   vsce publish            # or: vsce publish --pat <TOKEN>
   ```

`vsce publish [major|minor|patch]` bumps `package.json` and tags in one step.

### Tier 3 — CI automation (recommended)

A workflow triggered on a `vscode/v*` tag:

1. `npm ci && vsce package` → upload the `.vsix` as a GitHub Release asset.
2. `vsce publish` using a `VSCE_PAT` repository secret.

Release then reduces to:

```bash
git tag vscode/v0.1.0 && git push --tags
```

**Prerequisites for Tier 2/3** (one-time, manual):
- Register the `0al-spec` publisher on the Marketplace site.
- Add a `VSCE_PAT` secret under repo Settings → Secrets and variables → Actions.

## Swift CLI / library

The library is consumed directly by SwiftPM tag:

```swift
.package(url: "https://github.com/0al-spec/Hypercode", from: "0.4.0")
```

A release is a semver git tag on `main`. The VS Code extension's `serverInfo`
version (currently `0.4.0`, see `LSPServer.swift`) should track the CLI release
it was tested against.

## Versioning

- **CLI / library** — semver git tags (`0.4.0`, …); the IR carries its own
  schema version (`hypercode.ir/v1`), independent of the package version.
- **Extension** — `editors/vscode/package.json` `version`, released under
  `vscode/v*` tags so it can move independently of the CLI.
