# Hypercode — VS Code extension

Language support for Hypercode `.hc` / `.hcs` files: **live diagnostics** from the
Hypercode language server (`hypercode lsp`), over the standard Language Server
Protocol.

It is a thin client — all the language logic lives in the Swift
[`hypercode`](https://github.com/0al-spec/Hypercode) binary, so the same server
works in any LSP editor.

## Requirements

The `hypercode` CLI must be installed and support `hypercode lsp`:

```bash
git clone https://github.com/0al-spec/Hypercode && cd Hypercode
swift build -c release      # produces .build/release/hypercode
```

Put `hypercode` on your `PATH`, or set `hypercode.serverPath` to its absolute path.

## Develop

```bash
cd editors/vscode
npm install
npm run compile
# then press F5 in VS Code to launch the Extension Development Host
```

## Settings

- `hypercode.serverPath` — path to the `hypercode` executable (default: `hypercode`).

## Release

Packaging (`.vsix`), Marketplace publishing, and CI automation are documented in
[`DOCS/Release.md`](https://github.com/0al-spec/Hypercode/blob/main/DOCS/Release.md)
(the relative path is `../../DOCS/Release.md` in the repo; an absolute URL is used
here so the link also resolves in the packaged Marketplace README).
