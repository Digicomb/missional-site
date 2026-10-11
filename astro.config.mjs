// @ts-check
import { defineConfig } from 'astro/config';

// Step 1: served from https://kellyorr.github.io/missional-site/
// Step 2 (custom domain): change site to 'https://missional.io' and remove base.
export default defineConfig({
	site: 'https://kellyorr.github.io',
	base: '/missional-site',
});
