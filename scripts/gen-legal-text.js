// Writes website/src/legalText.js from the app's legal_pages.dart, so the
// website's Privacy policy and Disclaimer match the app's word for word.
// Run from the repo root after editing the Dart text:
//   node scripts/gen-legal-text.js
const fs = require('fs');
const src = fs.readFileSync('mobile/lib/features/legal/legal_pages.dart', 'utf8');

const str = (s) => s.replace(/\\'/g, "'").replace(/\\\$/g, '$');
const effective = src.match(/const kLegalEffectiveDate = '([^']*)';/)[1];

function sections(name) {
  const start = src.indexOf(`const ${name} = [`);
  const end = src.indexOf('\n];', start);
  const body = src.slice(start, end);
  const out = [];
  const re = /LegalSection\('((?:\\'|[^'])*)', \[([\s\S]*?)\n  \]\)/g;
  let m;
  while ((m = re.exec(body))) {
    const paras = [...m[2].matchAll(/'((?:\\'|[^'])*)',/g)].map((p) => str(p[1]));
    out.push({ heading: str(m[1]), paragraphs: paras });
  }
  return out;
}

const legal = { effective, privacy: sections('privacyPolicySections'), disclaimer: sections('disclaimerSections') };
fs.writeFileSync(
  'website/src/legalText.js',
  '// Generated from mobile/lib/features/legal/legal_pages.dart - keep the two in step.\n' +
    'const legal = ' + JSON.stringify(legal, null, 2) + ';\n\nexport default legal;\n',
);
