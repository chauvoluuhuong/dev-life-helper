import { spawn } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

export type ScriptLanguage = "AppleScript" | "JavaScript";
export type OutputStyle = "human" | "source";

export interface OsascriptInlineOptions {
  language: ScriptLanguage;
  script: string;
  args?: string[];
  timeoutMs?: number;
  outputStyle?: OutputStyle;
  cwd?: string;
}

export interface OsascriptFileOptions {
  scriptPath: string;
  language?: ScriptLanguage;
  args?: string[];
  timeoutMs?: number;
  outputStyle?: OutputStyle;
  cwd?: string;
}

export interface OsascriptResult {
  stdout: string;
  stderr: string;
  exitCode: number | null;
  timedOut: boolean;
  durationMs: number;
}

const DEFAULT_TIMEOUT_MS = 30_000;

/**
 * Executes inline AppleScript or JXA via `/usr/bin/osascript`, piping the script
 * over stdin so multi-line scripts and `argv` arguments work seamlessly without
 * shell escaping issues.
 */
export async function executeInlineOsascript(
  options: OsascriptInlineOptions
): Promise<OsascriptResult> {
  const {
    language,
    script,
    args = [],
    timeoutMs = DEFAULT_TIMEOUT_MS,
    outputStyle = "human",
    cwd,
  } = options;

  const styleFlag = outputStyle === "source" ? "s" : "h";
  const cliArgs = [
    "-l",
    language,
    "-s",
    styleFlag,
    "-",
    ...args,
  ];

  return runProcess("/usr/bin/osascript", cliArgs, {
    stdinContent: script,
    timeoutMs,
    cwd,
  });
}

/**
 * Executes an AppleScript or JXA script file via `/usr/bin/osascript`.
 */
export async function executeFileOsascript(
  options: OsascriptFileOptions
): Promise<OsascriptResult> {
  const {
    scriptPath,
    language,
    args = [],
    timeoutMs = DEFAULT_TIMEOUT_MS,
    outputStyle = "human",
    cwd,
  } = options;

  const styleFlag = outputStyle === "source" ? "s" : "h";
  const cliArgs: string[] = [];

  if (language) {
    cliArgs.push("-l", language);
  }
  cliArgs.push("-s", styleFlag, scriptPath, ...args);

  return runProcess("/usr/bin/osascript", cliArgs, {
    timeoutMs,
    cwd,
  });
}

/**
 * Validates AppleScript or JXA syntax using `/usr/bin/osacompile` without
 * executing the script.
 */
export async function validateOsascriptSyntax(options: {
  language: ScriptLanguage;
  script: string;
  timeoutMs?: number;
}): Promise<{ valid: boolean; stderr: string; durationMs: number }> {
  const { language, script, timeoutMs = 10_000 } = options;
  const tempDir = await mkdtemp(join(tmpdir(), "osacompile-"));
  const outputFile = join(tempDir, "compiled.scpt");

  try {
    const result = await runProcess(
      "/usr/bin/osacompile",
      ["-l", language, "-o", outputFile, "-"],
      {
        stdinContent: script,
        timeoutMs,
      }
    );

    return {
      valid: result.exitCode === 0 && !result.timedOut,
      stderr: result.stderr.trim(),
      durationMs: result.durationMs,
    };
  } finally {
    await rm(tempDir, { recursive: true, force: true }).catch(() => {});
  }
}

interface RunProcessOptions {
  stdinContent?: string;
  timeoutMs: number;
  cwd?: string;
}

function runProcess(
  command: string,
  args: string[],
  options: RunProcessOptions
): Promise<OsascriptResult> {
  const { stdinContent, timeoutMs, cwd } = options;
  const startTime = Date.now();

  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: cwd || process.cwd(),
      stdio: ["pipe", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    let timedOut = false;

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
      setTimeout(() => {
        if (!child.killed) {
          child.kill("SIGKILL");
        }
      }, 1000).unref();
    }, timeoutMs);

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");

    child.stdout.on("data", (chunk: string) => {
      stdout += chunk;
    });

    child.stderr.on("data", (chunk: string) => {
      stderr += chunk;
    });

    child.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });

    child.on("close", (exitCode) => {
      clearTimeout(timer);
      resolve({
        stdout: stdout.replace(/\r?\n$/, ""),
        stderr: stderr.replace(/\r?\n$/, ""),
        exitCode,
        timedOut,
        durationMs: Date.now() - startTime,
      });
    });

    if (stdinContent !== undefined) {
      child.stdin.write(stdinContent, "utf8");
    }
    child.stdin.end();
  });
}
