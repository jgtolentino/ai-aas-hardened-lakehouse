export function writeJUnit(results: any[]) {
  const tests = results.length;
  const failures = results.filter(r => r.status === "failed").length;
  const cases = results.map(r =>
    `<testcase classname="qa" name="browser:${r.browser}">${
      r.status === "failed" ? `<failure message="failed"/>` : ""
    }</testcase>`
  ).join("");
  
  return `<?xml version="1.0" encoding="UTF-8"?>
<testsuite tests="${tests}" failures="${failures}">
${cases}
</testsuite>`;
}