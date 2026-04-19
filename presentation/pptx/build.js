// Build PPTX from HTML slides using html2pptx
const path = require('path');
const fs = require('fs');
const pptxgen = require('pptxgenjs');

const SKILL_DIR = '/Users/jamicque/.claude/plugins/cache/anthropic-agent-skills/document-skills/69c0b1a06741/skills/pptx';
const html2pptx = require(path.join(SKILL_DIR, 'scripts', 'html2pptx.js'));

async function build() {
  const pptx = new pptxgen();
  pptx.layout = 'LAYOUT_16x9';
  pptx.title = 'Docker i Kubernetes — szkolenie';
  pptx.author = 'Maciej Krajewski';
  pptx.company = 'jsystems.pl';

  const htmlDir = path.join(__dirname, 'html');
  const slides = fs.readdirSync(htmlDir)
    .filter(f => f.endsWith('.html'))
    .sort();

  console.log(`==> Building PPTX from ${slides.length} HTML slides`);
  for (const f of slides) {
    process.stdout.write(`    ${f} ... `);
    await html2pptx(path.join(htmlDir, f), pptx);
    console.log('OK');
  }

  const out = path.join(__dirname, 'dist', 'k8s-training-2026.pptx');
  await pptx.writeFile({ fileName: out });
  console.log(`==> Saved: ${out}`);
}

build().catch(e => { console.error(e); process.exit(1); });
