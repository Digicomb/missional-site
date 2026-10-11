const sharp = require('sharp');
const fs = require('fs');
// Regenerate with: node scripts/make-og-image.cjs
const root = require('path').resolve(__dirname, '..');
const out = `${root}/public/og-image.jpg`;
const logo = fs.readFileSync(`${root}/public/favicon.svg`, 'utf8')
	.replace('<svg ', '<svg x="72" y="70" width="96" height="96" ');
const overlay = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
	<defs><linearGradient id="g" x1="0" x2="1">
		<stop offset="0" stop-color="#0f2236" stop-opacity="0.95"/>
		<stop offset="0.6" stop-color="#0f2236" stop-opacity="0.75"/>
		<stop offset="1" stop-color="#0f2236" stop-opacity="0.3"/>
	</linearGradient></defs>
	<rect width="1200" height="630" fill="url(#g)"/>
	${logo}
	<text x="184" y="136" font-family="Segoe UI, Arial, sans-serif" font-size="52" font-weight="700" fill="#fff">Missional</text>
	<text font-family="Segoe UI, Arial, sans-serif" font-size="64" font-weight="700" fill="#fff">
		<tspan x="72" y="320">Plan, fund and lead</tspan>
		<tspan x="72" y="400">mission trips, all in</tspan>
		<tspan x="72" y="480">one place.</tspan>
	</text>
	<text x="72" y="560" font-family="Segoe UI, Arial, sans-serif" font-size="30" font-weight="600" fill="#7cc6ec">missional.io</text>
</svg>`;
sharp(`${root}/src/assets/team-sunset.png`)
	.resize(1200, 630, { fit: 'cover', position: 'centre' })
	.composite([{ input: Buffer.from(overlay) }])
	.jpeg({ quality: 82 })
	.toFile(out)
	.then((i) => console.log(i.width, i.height, i.size));
