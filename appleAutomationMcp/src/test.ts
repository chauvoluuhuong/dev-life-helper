import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serverEntry = join(__dirname, "index.js");

test("apple-automation-mcp end-to-end tool tests", async (t) => {
  const testScriptsDir = await mkdtemp(join(tmpdir(), "mcp-saved-scripts-"));

  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [serverEntry],
    env: {
      ...(process.env as Record<string, string>),
      APPLE_AUTOMATION_SCRIPTS_DIR: testScriptsDir,
    },
  });

  const client = new Client(
    { name: "test-client", version: "1.1.0" },
    { capabilities: {} }
  );

  await client.connect(transport);

  t.after(async () => {
    await client.close();
    await rm(testScriptsDir, { recursive: true, force: true });
  });

  await t.test("lists expected tools", async () => {
    const { tools } = await client.listTools();
    const names = tools.map((tool) => tool.name).sort();
    assert.deepEqual(names, [
      "delete_saved_script",
      "get_saved_script",
      "list_saved_scripts",
      "run_applescript",
      "run_jxa",
      "run_osascript_file",
      "run_saved_script",
      "save_script",
      "validate_osascript",
    ]);
  });

  await t.test("executes inline AppleScript with arguments", async () => {
    const res = await client.callTool({
      name: "run_applescript",
      arguments: {
        script: `on run argv
  set a to item 1 of argv as integer
  set b to item 2 of argv as integer
  return "Sum: " & (a + b)
end run`,
        args: ["15", "27"],
      },
    });
    assert.equal(res.isError, undefined);
    const text = (res.content as Array<{ type: string; text: string }>)[0].text;
    assert.equal(text, "Sum: 42");
  });

  await t.test("executes inline JXA with arguments", async () => {
    const res = await client.callTool({
      name: "run_jxa",
      arguments: {
        script: `function run(argv) {
  return JSON.stringify({ args: argv, platform: "macOS" });
}`,
        args: ["alpha", "beta"],
      },
    });
    assert.equal(res.isError, undefined);
    const text = (res.content as Array<{ type: string; text: string }>)[0].text;
    assert.deepEqual(JSON.parse(text), {
      args: ["alpha", "beta"],
      platform: "macOS",
    });
  });

  await t.test("executes script file via run_osascript_file", async () => {
    const tempDir = await mkdtemp(join(tmpdir(), "mcp-osascript-test-"));
    try {
      const scriptFile = join(tempDir, "hello.applescript");
      await writeFile(
        scriptFile,
        `on run argv\n  return "Hello, " & (item 1 of argv) & "!"\nend run\n`,
        "utf8"
      );

      const res = await client.callTool({
        name: "run_osascript_file",
        arguments: {
          scriptPath: scriptFile,
          args: ["Antigravity"],
        },
      });
      assert.equal(res.isError, undefined);
      const text = (res.content as Array<{ type: string; text: string }>)[0].text;
      assert.equal(text, "Hello, Antigravity!");
    } finally {
      await rm(tempDir, { recursive: true, force: true });
    }
  });

  await t.test("validates valid and invalid AppleScript syntax", async () => {
    const validRes = await client.callTool({
      name: "validate_osascript",
      arguments: {
        language: "AppleScript",
        script: 'tell application "Finder" to get name of startup disk',
      },
    });
    assert.equal(validRes.isError, undefined);

    const invalidRes = await client.callTool({
      name: "validate_osascript",
      arguments: {
        language: "AppleScript",
        script: "tell application",
      },
    });
    assert.equal(invalidRes.isError, true);
  });

  await t.test("saves, lists, reads, runs, and deletes <name>_<description> script", async () => {
    // 1. Save script
    const saveRes = await client.callTool({
      name: "save_script",
      arguments: {
        name: "greet-user",
        description: "returns a greeting for the given user name",
        language: "AppleScript",
        script: `on run argv
  return "Welcome back, " & (item 1 of argv) & "!"
end run`,
      },
    });
    assert.equal(saveRes.isError, undefined);
    const saveText = (saveRes.content as Array<{ type: string; text: string }>)[0].text;
    assert.match(
      saveText,
      /greet-user_returns-a-greeting-for-the-given-user-name\.applescript/
    );

    // 2. List saved scripts
    const listRes = await client.callTool({
      name: "list_saved_scripts",
      arguments: {},
    });
    assert.equal(listRes.isError, undefined);
    const listText = (listRes.content as Array<{ type: string; text: string }>)[0].text;
    assert.match(
      listText,
      /greet-user_returns-a-greeting-for-the-given-user-name\.applescript/
    );

    // 3. Get saved script content
    const getRes = await client.callTool({
      name: "get_saved_script",
      arguments: {
        identifier: "greet-user",
      },
    });
    assert.equal(getRes.isError, undefined);
    const getText = (getRes.content as Array<{ type: string; text: string }>)[0].text;
    assert.match(getText, /Welcome back/);

    // 4. Run saved script by short name
    const runRes = await client.callTool({
      name: "run_saved_script",
      arguments: {
        identifier: "greet-user",
        args: ["Huong"],
      },
    });
    assert.equal(runRes.isError, undefined);
    const runText = (runRes.content as Array<{ type: string; text: string }>)[0].text;
    assert.equal(runText, "Welcome back, Huong!");

    // 5. Delete saved script
    const delRes = await client.callTool({
      name: "delete_saved_script",
      arguments: {
        identifier: "greet-user",
      },
    });
    assert.equal(delRes.isError, undefined);
  });
});
