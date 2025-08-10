import fs from "fs";
import path from "path";
import yaml from "js-yaml";
import { BrowserUseClient } from "./mcpClient.js";
import { writeJUnit } from "./reporters/junit.js";
import { upsertRun } from "./reporters/supabase.js";

const flowsDir = path.resolve(process.cwd(), "qa", "flows");
const artifactsDir = path.resolve(process.cwd(), "artifacts");
fs.mkdirSync(artifactsDir, { recursive: true });

// Helper functions
function normalizeCurrency(txt: string) { 
  return txt.replace(/[^\d.]/g, ""); 
}

// Make helpers available globally for eval
(globalThis as any).normalizeCurrency = normalizeCurrency;

async function runFlow(file: string) {
  console.log(`Running flow: ${file}`);
  const spec = yaml.load(fs.readFileSync(file, "utf8")) as any;
  const bu = new BrowserUseClient();
  
  // Parse browser matrix from env or setup
  const browserEnv = process.env.BROWSERS || spec.setup?.browserMatrix || "chrome";
  const matrix = browserEnv.split(",").map((s: string) => s.trim());
  const results: any[] = [];

  for (const browser of matrix) {
    console.log(`  Browser: ${browser}`);
    const ctx: any = { browser, artifactsDir };
    const steps = spec.steps || [];
    const logs: any[] = [];
    let status: "passed" | "failed" = "passed";
    
    // Inject base URL
    const baseUrl = spec.setup?.baseUrl?.replace("${QA_BASE_URL}", process.env.QA_BASE_URL || "") || "";

    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      const [op, payload] = Object.entries(step)[0] as [string, any];
      
      try {
        console.log(`    Step ${i + 1}: ${op}`);
        
        if (op === "navigate") {
          const url = payload.startsWith("http") ? payload : baseUrl + payload;
          await bu.navigate(url);
        } 
        else if (op === "click") {
          await bu.click(payload);
        } 
        else if (op === "type") {
          await bu.type(payload);
        } 
        else if (op === "waitFor") {
          await bu.waitFor(payload);
        } 
        else if (op === "extract") {
          const result = await bu.extract(payload);
          ctx[payload.as] = result.value;
        } 
        else if (op === "assert") {
          // Limited eval with injected helpers and context
          const condition = payload.condition;
          
          // Mock helpers for now - in real implementation these would come from MCP
          const url = "http://example.com/dashboard"; // Would be from browser state
          const innerText = (sel: string) => "Your Cart"; // Would be from DOM
          const document = { 
            title: "Test Page",
            querySelectorAll: (sel: string) => [1, 2, 3] // Mock
          };
          
          // Evaluate condition with context
          const pass = eval(condition);
          if (!pass) {
            throw new Error(payload.message || "Assertion failed");
          }
        } 
        else if (op === "screenshot") {
          const screenshotPath = payload.replace("${browser}", browser);
          await bu.screenshot(path.join(artifactsDir, screenshotPath));
        }
        
        logs.push({ step: i + 1, op, ok: true });
      } catch (e: any) {
        status = "failed";
        logs.push({ step: i + 1, op, ok: false, error: e.message });
        
        // Try to capture error screenshot
        try {
          await bu.screenshot(
            path.join(artifactsDir, `${spec.meta.id}_${browser}_error_step${i + 1}.png`)
          );
        } catch {}
        
        break; // Stop on first failure
      }
    }

    console.log(`    Result: ${status}`);
    results.push({ browser, status, logs });
    
    // Upload to Supabase
    try {
      await upsertRun(spec.meta?.id || path.basename(file), browser, status, logs);
    } catch (e) {
      console.error("Failed to upload results:", e);
    }
  }

  // Write reports
  const junitPath = path.join(artifactsDir, `${path.basename(file, ".yaml")}.junit.xml`);
  fs.writeFileSync(junitPath, writeJUnit(results));
  
  const jsonPath = path.join(artifactsDir, `${path.basename(file, ".yaml")}.report.json`);
  fs.writeFileSync(jsonPath, JSON.stringify({ 
    flow: file, 
    meta: spec.meta,
    results 
  }, null, 2));
  
  console.log(`  Reports: ${junitPath}, ${jsonPath}\n`);
}

// Main execution
(async () => {
  console.log("QA Browser-Use Runner\n");
  
  // Get flow files from args or scan directory
  const files = process.argv.slice(2).length > 0 
    ? process.argv.slice(2)
    : fs.readdirSync(flowsDir)
        .filter(f => f.endsWith(".yaml"))
        .map(f => path.join(flowsDir, f));
  
  console.log(`Found ${files.length} flow(s) to run\n`);
  
  for (const file of files) {
    await runFlow(file);
  }
  
  console.log("All flows completed!");
})();