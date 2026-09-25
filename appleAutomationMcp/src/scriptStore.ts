import { access, mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { basename, dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  type ScriptLanguage,
  validateOsascriptSyntax,
} from "./osascript.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
export const DEFAULT_SCRIPTS_DIR =
  process.env.APPLE_AUTOMATION_SCRIPTS_DIR ||
  resolve(__dirname, "..", "scripts");

export interface SaveScriptOptions {
  name: string;
  description: string;
  script: string;
  language?: ScriptLanguage;
  overwrite?: boolean;
  validateBeforeSave?: boolean;
  scriptsDir?: string;
}

export interface SavedScriptMetadata {
  name: string;
  description: string;
  fileName: string;
  filePath: string;
  language: ScriptLanguage;
}

/**
 * Sanitizes a segment (name or description) so it is safe for filenames.
 */
export function sanitizeSegment(value: string): string {
  const cleaned = value
    .trim()
    .replace(/[/\\:*?"<>|]+/g, "-")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^[-_]+|[-_]+$/g, "");

  if (!cleaned) {
    throw new Error("Script name and description must not be empty.");
  }
  return cleaned;
}

/**
 * Builds the `<name>_<description>.<ext>` filename.
 */
export function buildScriptFileName(
  name: string,
  description: string,
  language: ScriptLanguage
): string {
  const safeName = sanitizeSegment(name);
  const safeDescription = sanitizeSegment(description);
  const ext = language === "JavaScript" ? ".js" : ".applescript";
  return `${safeName}_${safeDescription}${ext}`;
}

function buildMetadataHeader(
  name: string,
  description: string,
  language: ScriptLanguage
): string {
  const prefix = language === "JavaScript" ? "//" : "--";
  return [
    `${prefix} @name: ${name.trim().replace(/\r?\n/g, " ")}`,
    `${prefix} @description: ${description.trim().replace(/\r?\n/g, " ")}`,
    `${prefix} @language: ${language}`,
    "",
  ].join("\n");
}

function parseMetadataFromContent(
  content: string,
  fileName: string
): { name: string; description: string; language: ScriptLanguage; cleanScript: string } {
  const ext = extname(fileName).toLowerCase();
  const base = basename(fileName, ext);
  const underscoreIndex = base.indexOf("_");

  let fallbackName = base;
  let fallbackDesc = "";
  if (underscoreIndex !== -1) {
    fallbackName = base.slice(0, underscoreIndex);
    fallbackDesc = base.slice(underscoreIndex + 1);
  }

  let inferredLanguage: ScriptLanguage =
    ext === ".js" || ext === ".jxa" ? "JavaScript" : "AppleScript";

  const lines = content.split(/\r?\n/);
  let name = fallbackName;
  let description = fallbackDesc;
  let headerLinesCount = 0;

  for (let i = 0; i < Math.min(lines.length, 5); i++) {
    const line = lines[i];
    const nameMatch = line.match(/^(?:--|\/\/)\s*@name:\s*(.+)$/);
    if (nameMatch) {
      name = nameMatch[1].trim();
      headerLinesCount = i + 1;
      continue;
    }
    const descMatch = line.match(/^(?:--|\/\/)\s*@description:\s*(.+)$/);
    if (descMatch) {
      description = descMatch[1].trim();
      headerLinesCount = i + 1;
      continue;
    }
    const langMatch = line.match(/^(?:--|\/\/)\s*@language:\s*(AppleScript|JavaScript)$/);
    if (langMatch) {
      inferredLanguage = langMatch[1] as ScriptLanguage;
      headerLinesCount = i + 1;
      continue;
    }
  }

  let cleanScript = content;
  if (headerLinesCount > 0) {
    const remaining = lines.slice(headerLinesCount);
    if (remaining[0] === "") {
      remaining.shift();
    }
    cleanScript = remaining.join("\n");
  }

  return { name, description, language: inferredLanguage, cleanScript };
}

/**
 * Saves an AppleScript or JXA script to `<scriptsDir>/<name>_<description>.<ext>`
 * so it can be reused later.
 */
export async function saveScript(
  options: SaveScriptOptions
): Promise<SavedScriptMetadata> {
  const {
    name,
    description,
    script,
    language = "AppleScript",
    overwrite = true,
    validateBeforeSave = true,
    scriptsDir = DEFAULT_SCRIPTS_DIR,
  } = options;

  if (validateBeforeSave) {
    const validation = await validateOsascriptSyntax({ language, script });
    if (!validation.valid) {
      throw new Error(
        `${language} syntax error: ${validation.stderr || "Compilation failed."}`
      );
    }
  }

  await mkdir(scriptsDir, { recursive: true });

  const fileName = buildScriptFileName(name, description, language);
  const filePath = join(scriptsDir, fileName);

  if (!overwrite) {
    try {
      await access(filePath);
      throw new Error(
        `Script file '${fileName}' already exists. Pass overwrite=true to replace it.`
      );
    } catch (err) {
      if (err instanceof Error && err.message.includes("already exists")) {
        throw err;
      }
    }
  }

  const header = buildMetadataHeader(name, description, language);
  const fullContent = `${header}${script.trimEnd()}\n`;
  await writeFile(filePath, fullContent, "utf8");

  return {
    name: name.trim(),
    description: description.trim(),
    fileName,
    filePath,
    language,
  };
}

/**
 * Lists all saved scripts in `scriptsDir`.
 */
export async function listSavedScripts(
  scriptsDir: string = DEFAULT_SCRIPTS_DIR
): Promise<SavedScriptMetadata[]> {
  try {
    await access(scriptsDir);
  } catch {
    return [];
  }

  const entries = await readdir(scriptsDir, { withFileTypes: true });
  const results: SavedScriptMetadata[] = [];

  for (const entry of entries) {
    if (!entry.isFile()) continue;
    const ext = extname(entry.name).toLowerCase();
    if (![".applescript", ".js", ".jxa", ".scpt"].includes(ext)) continue;

    const filePath = join(scriptsDir, entry.name);
    let name = entry.name;
    let description = "";
    let language: ScriptLanguage =
      ext === ".js" || ext === ".jxa" ? "JavaScript" : "AppleScript";

    if (ext !== ".scpt") {
      try {
        const content = await readFile(filePath, "utf8");
        const parsed = parseMetadataFromContent(content, entry.name);
        name = parsed.name;
        description = parsed.description;
        language = parsed.language;
      } catch {
        // Fallback to filename parsing
      }
    } else {
      const base = basename(entry.name, ext);
      const idx = base.indexOf("_");
      name = idx !== -1 ? base.slice(0, idx) : base;
      description = idx !== -1 ? base.slice(idx + 1) : "";
    }

    results.push({
      name,
      description,
      fileName: entry.name,
      filePath,
      language,
    });
  }

  return results.sort((a, b) => a.fileName.localeCompare(b.fileName));
}

/**
 * Finds a saved script by exact fileName, `<name>_<description>` base name,
 * or script `name`.
 */
export async function findSavedScript(
  identifier: string,
  scriptsDir: string = DEFAULT_SCRIPTS_DIR
): Promise<SavedScriptMetadata | null> {
  const scripts = await listSavedScripts(scriptsDir);
  const query = identifier.trim();
  const normalizedQuery = query.toLowerCase();
  const sanitizedQuery = (() => {
    try {
      return sanitizeSegment(query).toLowerCase();
    } catch {
      return normalizedQuery;
    }
  })();

  // 1. Exact fileName or baseName match
  for (const item of scripts) {
    const base = basename(item.fileName, extname(item.fileName));
    if (
      item.fileName.toLowerCase() === normalizedQuery ||
      base.toLowerCase() === normalizedQuery
    ) {
      return item;
    }
  }

  // 2. Exact name match (raw or sanitized)
  for (const item of scripts) {
    const base = basename(item.fileName, extname(item.fileName));
    const filePrefix = base.split("_")[0]?.toLowerCase();
    if (
      item.name.toLowerCase() === normalizedQuery ||
      filePrefix === sanitizedQuery ||
      filePrefix === normalizedQuery
    ) {
      return item;
    }
  }

  // 3. Partial match on fileName or description
  for (const item of scripts) {
    if (
      item.fileName.toLowerCase().includes(normalizedQuery) ||
      item.description.toLowerCase().includes(normalizedQuery)
    ) {
      return item;
    }
  }

  return null;
}

/**
 * Reads a saved script's metadata and source code.
 */
export async function getSavedScript(
  identifier: string,
  scriptsDir: string = DEFAULT_SCRIPTS_DIR
): Promise<{ metadata: SavedScriptMetadata; script: string }> {
  const match = await findSavedScript(identifier, scriptsDir);
  if (!match) {
    throw new Error(`Saved script '${identifier}' not found in ${scriptsDir}.`);
  }

  const rawContent = await readFile(match.filePath, "utf8");
  const { cleanScript } = parseMetadataFromContent(rawContent, match.fileName);
  return {
    metadata: match,
    script: cleanScript,
  };
}

/**
 * Deletes a saved script by identifier.
 */
export async function deleteSavedScript(
  identifier: string,
  scriptsDir: string = DEFAULT_SCRIPTS_DIR
): Promise<SavedScriptMetadata> {
  const match = await findSavedScript(identifier, scriptsDir);
  if (!match) {
    throw new Error(`Saved script '${identifier}' not found in ${scriptsDir}.`);
  }
  await rm(match.filePath, { force: true });
  return match;
}
