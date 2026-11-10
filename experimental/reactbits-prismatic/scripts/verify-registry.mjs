import fs from 'node:fs';
const p = JSON.parse(fs.readFileSync(new URL('../components.json', import.meta.url), 'utf8'));
const registries = ['@reactbits-starter','@reactbits-pro'];
let ok = true;
for (const name of registries) {
  const r = p.registries?.[name];
  const segment = name === '@reactbits-starter' ? 'starter' : 'pro';
  if (r?.url !== `https://pro.reactbits.dev/api/r/${segment}/{name}.json` ||
      r?.headers?.Authorization !== 'Bearer ${REACTBITS_LICENSE_KEY}') {
    console.error(`CONFIG_FAIL: ${name}`); ok = false;
  }
}
const keySet = Boolean(process.env.REACTBITS_LICENSE_KEY);
console.log('REGISTRY_CONFIG=' + (ok ? 'PASS' : 'FAIL'));
console.log('REACTBITS_LICENSE_KEY=' + (keySet ? 'SET' : 'MISSING'));
if (!ok) process.exit(1);
