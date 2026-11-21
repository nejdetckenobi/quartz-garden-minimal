FROM node:22-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/quartz
RUN git clone --branch v5 --single-branch --depth 1 https://github.com/jackyzha0/quartz.git . \
    && npm ci

COPY --chmod=755 <<'EOF' /usr/local/bin/build-garden
#!/bin/sh
set -eu

if [ ! -d /dist ]; then
    echo 'Mount an empty output directory at /dist.' >&2
    exit 1
fi
existing=$(find /dist -mindepth 1 -maxdepth 1 -print -quit)
if [ -n "$existing" ]; then
    echo 'The output directory /dist must be empty.' >&2
    exit 1
fi

output=$(mktemp -d)
trap 'rm -rf "$output"' EXIT
node quartz/bootstrap-cli.mjs build --directory content --output "$output"
if [ ! -s "$output/index.html" ]; then
    echo 'Quartz did not generate index.html. Check content/index.md and the Quartz config.' >&2
    exit 1
fi

# Serve Quartz's extensionless links on static servers that support directory indexes.
node --input-type=module - "$output" <<'JS'
import { existsSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs'
import { join, relative } from 'node:path'

const output = process.argv[2]
for (const entry of readdirSync(output, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.html') || entry.name === 'index.html') continue
    if (entry.name === '404.html' && entry.parentPath === output) continue

    const directory = join(entry.parentPath, entry.name.slice(0, -'.html'.length))
    const index = join(directory, 'index.html')
    if (existsSync(index)) {
        throw new Error(`Quartz route /${relative(output, directory)} already has an index.html`)
    }

    const target = `../${encodeURIComponent(entry.name)}`
    mkdirSync(directory, { recursive: true })
    writeFileSync(index, `<!doctype html>
<meta charset="utf-8">
<title>Redirect</title>
<script>location.replace(${JSON.stringify(target)} + location.search + location.hash)</script>
<noscript><meta http-equiv="refresh" content="0; url=${target}"></noscript>
<a href="${target}">${encodeURIComponent(entry.name)}</a>
`, { flag: 'wx' })
}
JS

cp -R -- "$output/." /dist/
chown -R --reference=/dist /dist
EOF

ENTRYPOINT ["/usr/local/bin/build-garden"]
