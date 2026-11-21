# Recipe Garden

Run these commands from the project root. Docker is the only build dependency on the host.

## 1. Build the Docker image

```sh
docker build -t quartz-builder - < Dockerfile
```

## 2. Build the site

Start with an empty `dist/` directory. If it contains output from a previous build, move that output elsewhere before continuing.

```sh
mkdir -p dist
docker run --rm --network none \
  --mount "type=bind,src=$PWD/content,dst=/opt/quartz/content,readonly" \
  --mount "type=bind,src=$PWD/quartz.config.yaml,dst=/opt/quartz/quartz.config.yaml,readonly" \
  --mount "type=bind,src=$PWD/dist,dst=/dist" \
  quartz-builder
```

The container mounts the content and configuration as read-only. It writes the static site to `dist/`, with `dist/index.html` as the home page.
