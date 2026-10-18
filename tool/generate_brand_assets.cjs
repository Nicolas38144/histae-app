// Render the approved vector sources; no fonts or image service are involved.
// Requires sharp on Node's module path. Optionally pass --site <histae-site>.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const source = path.join(root, 'pictures/logos/nouvelle-da/02-les-pages');
const brand = path.join(root, 'assets/branding');
const siteIndex = process.argv.indexOf('--site');
const site = siteIndex < 0 ? null : path.resolve(process.argv[siteIndex + 1]);

async function write(file, content) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, content);
}

async function png(svg, size, target) {
  const image = sharp(Buffer.from(svg)).resize(size, size);
  await write(target, await image.removeAlpha().png().toBuffer());
}

async function main() {
  const symbol = await fs.readFile(path.join(source, 'symbole.svg'), 'utf8');
  const body = symbol.slice(symbol.indexOf('<g '), symbol.lastIndexOf('</svg>'));
  const icon = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#0D1421"/><g transform="translate(160 185.4375) scale(5.5)">${body}</g></svg>`;
  await write(path.join(brand, 'histae-logo.svg'), symbol);
  await write(path.join(brand, 'histae-icon.svg'), icon);
  await png(icon, 1024, path.join(brand, 'histae-icon.png'));
  for (const [variant, original] of [['dark', 'sombre'], ['light', 'clair']]) {
    const signature = (await fs.readFile(path.join(source, `logo-${original}.svg`), 'utf8'))
      .replace('width="540" height="176" viewBox="0 0 540 176"', 'width="440" height="108" viewBox="34 30 440 108"');
    await write(path.join(brand, `histae-signature-${variant}.svg`), signature);
    await write(path.join(brand, `histae-signature-${variant}.png`),
      await sharp(Buffer.from(signature)).resize(880, 216).png().toBuffer());
    if (site && variant === 'dark') {
      await write(path.join(site, 'public/branding/histae-signature.svg'), signature);
    }
  }
  for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    await png(icon, size, path.join(root, `android/app/src/main/res/mipmap-${density}/ic_launcher.png`));
  }
  const ios = path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const catalog = JSON.parse(await fs.readFile(path.join(ios, 'Contents.json'), 'utf8'));
  for (const entry of catalog.images) {
    const size = Math.round(parseFloat(entry.size) * parseFloat(entry.scale));
    await png(icon, size, path.join(ios, entry.filename));
  }
  if (site) {
    const favicon = icon.replace('width="1024" height="1024"', 'width="64" height="64"');
    await write(path.join(site, 'public/branding/histae-logo.svg'), symbol);
    await write(path.join(site, 'public/branding/favicon.svg'), favicon);
    await png(icon, 48, path.join(site, 'public/branding/favicon.png'));
    await png(icon, 180, path.join(site, 'public/branding/apple-touch-icon.png'));
    await png(icon, 192, path.join(site, 'public/branding/icon-192.png'));
    await png(icon, 512, path.join(site, 'public/branding/icon-512.png'));
    await png(icon, 1024, path.join(site, 'public/logo.png'));
  }
  console.log('Approved book logo and native icon sizes generated.');
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
