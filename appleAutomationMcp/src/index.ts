#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { access } from "node:fs/promises";
import { extname, resolve } from "node:path";
import { z } from "zod";
import {
  executeFileOsascript,
  executeInlineOsascript,
  type OsascriptResult,
  type ScriptLanguage,
  validateOsascriptSyntax,
} from "./osascript.js";
import {
  DEFAULT_SCRIPTS_DIR,
  deleteSavedScript,
  findSavedScript,
  getSavedScript,
  listSavedScripts,
  saveScript,
} from "./scriptStore.js";

const server = new McpServer({
  name: "apple-automation-mcp",
  version: "1.1.0",
});

function formatExecutionResponse(result: OsascriptResult, timeoutMs: number) {
  if (result.timedOut) {
    return {
      isError: true,
      content: [
        {
          type: "text" as const,
          text: [
            `Execution timed out after ${timeoutMs}ms.`,
            result.stdout ? `STDOUT:\n${result.stdout}` : "",
            result.stderr ? `STDERR:\n${result.stderr}` : "",
          ]
            .filter(Boolean)
            .join("\n\n"),
        },
      ],
    };
  }

  if (result.exitCode !== 0) {
    return {
      isError: true,
      content: [
        {
          type: "text" as const,
          text: [
            `osascript exited with code ${result.exitCode} (${result.durationMs}ms).`,
            result.stderr ? `STDERR:\n${result.stderr}` : "",
            result.stdout ? `STDOUT:\n${result.stdout}` : "",
          ]
            .filter(Boolean)
            .join("\n\n"),
        },
      ],
    };
  }

  // Note: AppleScript `log` statements write to stderr even when exitCode is 0.
  const parts: string[] = [];
  if (result.stdout) {
    parts.push(result.stdout);
  }
  if (result.stderr) {
    parts.push(`[stderr / log]\n${result.stderr}`);
  }
  if (parts.length === 0) {
    parts.push(`Script executed successfully with no output (${result.durationMs}ms).`);
  }

  return {
    content: [
      {
        type: "text" as const,
        text: parts.join("\n\n"),
      },
    ],
  };
}

// Tool 1: run_applescript
server.tool(
  "run_applescript",
  "Execute inline AppleScript code on macOS via osascript. Supports multi-line scripts and passing arguments to `on run argv`.",
  {
    script: z
      .string()
      .min(1)
      .describe(
        "The AppleScript code to execute. Use `on run argv ... end run` if passing `args`."
      ),
    args: z
      .array(z.string())
      .optional()
      .describe("Optional list of string arguments passed to `on run argv`."),
    timeoutMs: z
      .number()
      .int()
      .positive()
      .max(300_000)
      .optional()
      .default(30_000)
      .describe("Execution timeout in milliseconds (default: 30000, max: 300000)."),
    outputStyle: z
      .enum(["human", "source"])
      .optional()
      .default("human")
      .describe(
        "Output formatting style: 'human' (-s h, default) for human-readable output or 'source' (-s s) for recompilable AppleScript source literals."
      ),
    cwd: z
      .string()
      .optional()
      .describe("Optional working directory for script execution."),
  },
  async ({ script, args, timeoutMs, outputStyle, cwd }) => {
    try {
      const result = await executeInlineOsascript({
        language: "AppleScript",
        script,
        args,
        timeoutMs,
        outputStyle,
        cwd,
      });
      return formatExecutionResponse(result, timeoutMs);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [{ type: "text", text: `Failed to execute AppleScript: ${message}` }],
      };
    }
  }
);

// Tool 2: run_jxa
server.tool(
  "run_jxa",
  "Execute inline JavaScript for Automation (JXA) code on macOS via `osascript -l JavaScript`. Supports interacting with macOS applications, ObjC bridge, and passing arguments to `function run(argv)`.",
  {
    script: z
      .string()
      .min(1)
      .describe(
        "The JXA (JavaScript for Automation) code to execute. Define `function run(argv) { ... }` if passing `args`."
      ),
    args: z
      .array(z.string())
      .optional()
      .describe("Optional list of string arguments passed to `function run(argv)`."),
    timeoutMs: z
      .number()
      .int()
      .positive()
      .max(300_000)
      .optional()
      .default(30_000)
      .describe("Execution timeout in milliseconds (default: 30000, max: 300000)."),
    outputStyle: z
      .enum(["human", "source"])
      .optional()
      .default("human")
      .describe("Output formatting style: 'human' (-s h, default) or 'source' (-s s)."),
    cwd: z
      .string()
      .optional()
      .describe("Optional working directory for script execution."),
  },
  async ({ script, args, timeoutMs, outputStyle, cwd }) => {
    try {
      const result = await executeInlineOsascript({
        language: "JavaScript",
        script,
        args,
        timeoutMs,
        outputStyle,
        cwd,
      });
      return formatExecutionResponse(result, timeoutMs);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [{ type: "text", text: `Failed to execute JXA script: ${message}` }],
      };
    }
  }
);

// Tool 3: run_osascript_file
server.tool(
  "run_osascript_file",
  "Execute an AppleScript (.applescript, .scpt, .scptd) or JXA (.js) file from disk via osascript.",
  {
    scriptPath: z
      .string()
      .min(1)
      .describe("Path to the script file (.applescript, .scpt, .scptd, or .js)."),
    language: z
      .enum(["AppleScript", "JavaScript"])
      .optional()
      .describe(
        "Script language override. If omitted, inferred from file extension (.js/.jxa -> JavaScript, otherwise AppleScript/compiled)."
      ),
    args: z
      .array(z.string())
      .optional()
      .describe("Optional arguments passed to the script's `run` handler."),
    timeoutMs: z
      .number()
      .int()
      .positive()
      .max(300_000)
      .optional()
      .default(30_000)
      .describe("Execution timeout in milliseconds (default: 30000, max: 300000)."),
    outputStyle: z
      .enum(["human", "source"])
      .optional()
      .default("human")
      .describe("Output formatting style: 'human' (-s h, default) or 'source' (-s s)."),
    cwd: z
      .string()
      .optional()
      .describe("Optional working directory for script execution."),
  },
  async ({ scriptPath, language, args, timeoutMs, outputStyle, cwd }) => {
    try {
      const resolvedPath = resolve(cwd || process.cwd(), scriptPath);
      await access(resolvedPath);

      let inferredLanguage: ScriptLanguage | undefined = language;
      if (!inferredLanguage) {
        const ext = extname(resolvedPath).toLowerCase();
        if (ext === ".js" || ext === ".jxa") {
          inferredLanguage = "JavaScript";
        } else if (ext === ".applescript") {
          inferredLanguage = "AppleScript";
        }
      }

      const result = await executeFileOsascript({
        scriptPath: resolvedPath,
        language: inferredLanguage,
        args,
        timeoutMs,
        outputStyle,
        cwd,
      });
      return formatExecutionResponse(result, timeoutMs);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [
          { type: "text", text: `Failed to execute script file '${scriptPath}': ${message}` },
        ],
      };
    }
  }
);

// Tool 4: validate_osascript
server.tool(
  "validate_osascript",
  "Compile-check inline AppleScript or JXA (JavaScript for Automation) code using `osacompile` to verify syntax without executing it.",
  {
    script: z.string().min(1).describe("The AppleScript or JXA code to syntax-check."),
    language: z
      .enum(["AppleScript", "JavaScript"])
      .optional()
      .default("AppleScript")
      .describe("Script language: 'AppleScript' (default) or 'JavaScript' (JXA)."),
  },
  async ({ script, language }) => {
    try {
      const result = await validateOsascriptSyntax({ language, script });
      if (result.valid) {
        return {
          content: [
            {
              type: "text",
              text: `${language} syntax is valid (checked in ${result.durationMs}ms).`,
            },
          ],
        };
      }
      return {
        isError: true,
        content: [
          {
            type: "text",
            text: `${language} syntax error:\n${result.stderr || "Compilation failed."}`,
          },
        ],
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [{ type: "text", text: `Syntax validation failed: ${message}` }],
      };
    }
  }
);

// Tool 5: save_script
server.tool(
  "save_script",
  "Save an AppleScript or JXA script with `<name>_<description>` naming so it can be reused later.",
  {
    name: z
      .string()
      .min(1)
      .describe("Short identifier name for the script (e.g. 'toggle-dark-mode')."),
    description: z
      .string()
      .min(1)
      .describe(
        "Brief description of what the script does (saved in filename as `<name>_<description>.<ext>`)."
      ),
    script: z
      .string()
      .min(1)
      .describe("The AppleScript or JXA source code to save."),
    language: z
      .enum(["AppleScript", "JavaScript"])
      .optional()
      .default("AppleScript")
      .describe("Script language: 'AppleScript' (default) or 'JavaScript' (JXA)."),
    overwrite: z
      .boolean()
      .optional()
      .default(true)
      .describe("Whether to overwrite an existing script with the same `<name>_<description>` filename (default: true)."),
    validateBeforeSave: z
      .boolean()
      .optional()
      .default(true)
      .describe("Whether to syntax-check the script via `osacompile` before saving (default: true)."),
  },
  async ({ name, description, script, language, overwrite, validateBeforeSave }) => {
    try {
      const saved = await saveScript({
        name,
        description,
        script,
        language,
        overwrite,
        validateBeforeSave,
      });
      return {
        content: [
          {
            type: "text",
            text: [
              `Saved ${saved.language} script as '${saved.fileName}'.`,
              `Name: ${saved.name}`,
              `Description: ${saved.description}`,
              `Path: ${saved.filePath}`,
            ].join("\n"),
          },
        ],
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [{ type: "text", text: `Failed to save script: ${message}` }],
      };
    }
  }
);

// Tool 6: list_saved_scripts
server.tool(
  "list_saved_scripts",
  "List all saved AppleScript and JXA scripts (`<name>_<description>`) available for reuse.",
  {},
  async () => {
    try {
      const scripts = await listSavedScripts();
      if (scripts.length === 0) {
        return {
          content: [
            {
              type: "text",
              text: `No saved scripts found in ${DEFAULT_SCRIPTS_DIR}. Use \`save_script\` to save one.`,
            },
          ],
        };
      }

      const formatted = scripts
        .map(
          (s, idx) =>
            `${idx + 1}. ${s.fileName} [${s.language}]\n   Name: ${s.name}\n   Description: ${s.description}\n   Path: ${s.filePath}`
        )
        .join("\n\n");

      return {
        content: [
          {
            type: "text",
            text: `Saved scripts (${scripts.length}):\n\n${formatted}`,
          },
        ],
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [{ type: "text", text: `Failed to list saved scripts: ${message}` }],
      };
    }
  }
);

// Tool 7: run_saved_script
server.tool(
  "run_saved_script",
  "Execute a previously saved script by its `name` or `<name>_<description>` filename.",
  {
    identifier: z
      .string()
      .min(1)
      .describe(
        "The saved script's `name`, `<name>_<description>`, or full filename (e.g. 'toggle-dark-mode' or 'toggle-dark-mode_switches-macos-appearance.applescript')."
      ),
    args: z
      .array(z.string())
      .optional()
      .describe("Optional arguments passed to the script's `run` handler."),
    timeoutMs: z
      .number()
      .int()
      .positive()
      .max(300_000)
      .optional()
      .default(30_000)
      .describe("Execution timeout in milliseconds (default: 30000, max: 300000)."),
    outputStyle: z
      .enum(["human", "source"])
      .optional()
      .default("human")
      .describe("Output formatting style: 'human' (-s h, default) or 'source' (-s s)."),
    cwd: z
      .string()
      .optional()
      .describe("Optional working directory for script execution."),
  },
  async ({ identifier, args, timeoutMs, outputStyle, cwd }) => {
    try {
      const saved = await findSavedScript(identifier);
      if (!saved) {
        return {
          isError: true,
          content: [
            {
              type: "text",
              text: `Saved script '${identifier}' not found. Call \`list_saved_scripts\` to see available scripts.`,
            },
          ],
        };
      }

      const result = await executeFileOsascript({
        scriptPath: saved.filePath,
        language: saved.language,
        args,
        timeoutMs,
        outputStyle,
        cwd,
      });
      return formatExecutionResponse(result, timeoutMs);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [
          {
            type: "text",
            text: `Failed to execute saved script '${identifier}': ${message}`,
          },
        ],
      };
    }
  }
);

// Tool 8: get_saved_script
server.tool(
  "get_saved_script",
  "Read the source code and metadata of a saved `<name>_<description>` script.",
  {
    identifier: z
      .string()
      .min(1)
      .describe("The saved script's `name`, `<name>_<description>`, or filename."),
  },
  async ({ identifier }) => {
    try {
      const { metadata, script } = await getSavedScript(identifier);
      return {
        content: [
          {
            type: "text",
            text: [
              `File: ${metadata.fileName}`,
              `Name: ${metadata.name}`,
              `Description: ${metadata.description}`,
              `Language: ${metadata.language}`,
              `Path: ${metadata.filePath}`,
              "",
              script,
            ].join("\n"),
          },
        ],
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [{ type: "text", text: `Failed to read saved script: ${message}` }],
      };
    }
  }
);

// Tool 9: delete_saved_script
server.tool(
  "delete_saved_script",
  "Delete a saved `<name>_<description>` script from the saved scripts library.",
  {
    identifier: z
      .string()
      .min(1)
      .describe("The saved script's `name`, `<name>_<description>`, or filename."),
  },
  async ({ identifier }) => {
    try {
      const removed = await deleteSavedScript(identifier);
      return {
        content: [
          {
            type: "text",
            text: `Deleted saved script '${removed.fileName}' (${removed.filePath}).`,
          },
        ],
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        isError: true,
        content: [{ type: "text", text: `Failed to delete saved script: ${message}` }],
      };
    }
  }
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("Fatal error starting apple-automation-mcp:", error);
  process.exit(1);
});
