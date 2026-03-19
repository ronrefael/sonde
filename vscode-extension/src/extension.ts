import * as vscode from 'vscode';
import { execSync } from 'child_process';

let statusBarItem: vscode.StatusBarItem;
let refreshInterval: NodeJS.Timeout | undefined;

/** Strip ANSI escape codes from a string. */
function stripAnsi(text: string): string {
    return text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');
}

/** Run sonde and capture its output. */
function getSondeOutput(): string {
    try {
        const result = execSync('echo \'{}\' | sonde', {
            timeout: 5000,
            encoding: 'utf-8',
            shell: '/bin/sh',
        });
        return stripAnsi(result).trim();
    } catch {
        return '';
    }
}

/** Parse sonde output into key metrics. */
function parseSondeOutput(output: string): {
    model?: string;
    cost?: string;
    pacing?: string;
} {
    const parts = output.split(/\s{2,}/);
    const result: { model?: string; cost?: string; pacing?: string } = {};

    for (const part of parts) {
        const trimmed = part.trim();
        if (trimmed.match(/^(Opus|Sonnet|Haiku)/)) {
            result.model = trimmed;
        } else if (trimmed.startsWith('$')) {
            result.cost = trimmed;
        } else if (trimmed.match(/(Comfortable|On Track|Elevated|Hot|Critical|Runaway)/)) {
            result.pacing = trimmed;
        }
    }

    return result;
}

function updateStatusBar(): void {
    const output = getSondeOutput();
    if (!output) {
        statusBarItem.text = '$(pulse) sonde';
        statusBarItem.tooltip = 'sonde: no data';
        return;
    }

    const metrics = parseSondeOutput(output);
    const parts: string[] = [];
    if (metrics.model) { parts.push(metrics.model); }
    if (metrics.cost) { parts.push(metrics.cost); }
    if (metrics.pacing) { parts.push(metrics.pacing); }

    statusBarItem.text = parts.length > 0 ? parts.join(' | ') : output.substring(0, 40);
    statusBarItem.tooltip = output;
}

export function activate(context: vscode.ExtensionContext): void {
    statusBarItem = vscode.window.createStatusBarItem(
        vscode.StatusBarAlignment.Left,
        100
    );
    statusBarItem.command = 'sonde.showDashboard';
    statusBarItem.text = '$(pulse) sonde';
    statusBarItem.show();

    context.subscriptions.push(statusBarItem);

    // Refresh every 30 seconds
    updateStatusBar();
    refreshInterval = setInterval(updateStatusBar, 30000);

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('sonde.showDashboard', () => {
            const output = getSondeOutput();
            if (output) {
                vscode.window.showInformationMessage(`sonde: ${output}`);
            } else {
                vscode.window.showWarningMessage('sonde: no data available. Is sonde installed?');
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('sonde.refresh', () => {
            updateStatusBar();
        })
    );
}

export function deactivate(): void {
    if (refreshInterval) {
        clearInterval(refreshInterval);
    }
}
