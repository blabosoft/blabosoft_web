BASEDIR=$(dirname $0)
BUILD_DIRNAME=$BASEDIR/.build_result
CONTENT_DIR=$BASEDIR/docs

mkdir --mode=777 --parents $BUILD_DIRNAME

# serve
podman run --rm \
  --volume="$BUILD_DIRNAME:/srv/jekyll_build" \
  --volume="$CONTENT_DIR:/srv/jekyll" \
  -p 8777:8777 \
  -it registry.hub.docker.com/jekyll/jekyll:latest \
  jekyll serve --port 8777 --destination /srv/jekyll_build --disable-disk-cache