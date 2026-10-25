import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const serviceRoot = fileURLToPath(new URL('../', import.meta.url));

test('Netlify build publishes a Tvium presentation and a separate phone pairing page', () => {
  execFileSync('npm', ['run', 'build:pairing'], { cwd: serviceRoot });

  const landing = readFileSync(new URL('../dist/index.html', import.meta.url), 'utf8');
  const pairing = readFileSync(new URL('../dist/pair/index.html', import.meta.url), 'utf8');

  assert.match(landing, /<h1\b[^>]*>.*Tvium.*<\/h1>/s);
  assert.match(landing, /https:\/\/bfmix\.github\.io\/Tvium\//);
  assert.match(landing, /href="\/pair\/"/);
  assert.match(pairing, /Add a source with your phone/);
  assert.doesNotMatch(landing, /playlist\.m3u|password|token/i);
});
