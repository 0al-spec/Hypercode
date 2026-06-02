import * as vscode from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind,
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export function activate(context: vscode.ExtensionContext): void {
    const serverPath = vscode.workspace
        .getConfiguration('hypercode')
        .get<string>('serverPath', 'hypercode');

    // The Hypercode language server is `hypercode lsp` over stdio.
    const server = { command: serverPath, args: ['lsp'], transport: TransportKind.stdio };
    const serverOptions: ServerOptions = { run: server, debug: server };

    const clientOptions: LanguageClientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'hypercode' },
            { scheme: 'file', language: 'hypercode-hcs' },
        ],
    };

    client = new LanguageClient(
        'hypercode',
        'Hypercode Language Server',
        serverOptions,
        clientOptions,
    );

    void client.start();
    context.subscriptions.push({ dispose: () => { void client?.stop(); } });
}

export function deactivate(): Thenable<void> | undefined {
    return client?.stop();
}
