import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const readSource = (relativePath) =>
  readFileSync(new URL(relativePath, import.meta.url), "utf8");

const nsrp = readSource("../src/App.jsx");
const resume = readSource("../src/ResumeApp.jsx");

assert.match(nsrp, /const \[fitScale, setFitScale\] = useState\(1\)/);
assert.match(nsrp, /const viewportWidth = document\.documentElement\.clientWidth \|\| window\.innerWidth/);
assert.match(nsrp, /\(viewportWidth - 32\) \/ 850/);
assert.match(nsrp, /id="peso-page-1" className="w-\[850px\]/);
assert.match(nsrp, /id="peso-page-2" className="w-\[850px\]/);
assert.ok(nsrp.includes("zoomLevel * fitScale"));
assert.match(nsrp, /zoomWrapper\.style\.transform = 'scale\(1\)'/);
assert.match(nsrp, /zoomWrapper\.style\.transform = originalTransform/);

assert.match(resume, /const \[fitScale, setFitScale\] = useState\(1\)/);
assert.match(resume, /const viewportWidth = document\.documentElement\.clientWidth \|\| window\.innerWidth/);
assert.match(resume, /\(viewportWidth - 48\) \/ 794/);
assert.match(resume, /id="resume-node" className="w-\[794px\] min-h-\[1123px\]/);
assert.ok(resume.includes("zoom * fitScale"));
assert.match(resume, /zoomWrapper\.style\.transform = 'scale\(1\)'/);
assert.match(resume, /zoomWrapper\.style\.transform = originalTransform/);

assert.match(resume, /flex flex-wrap items-center gap-2 min-w-0/);
assert.match(resume, /flex flex-wrap items-center gap-3/);
assert.match(nsrp, /flex flex-wrap items-center justify-center gap-2/);

console.log("PASS: 15 NSRP/resume responsive geometry and export-boundary assertions");
