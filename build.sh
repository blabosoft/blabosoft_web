CURRENT_DIR=$(dirname $0)
BUILD_DIRNAME=$HOME/temp/jekyll_blabo
CONTENT_DIR=$CURRENT_DIR/docs

CONTAINER_NAME=jekyll_blabo

mkdir --mode=777 --parents $BUILD_DIRNAME

podman stop $CONTAINER_NAME 
podman rm $CONTAINER_NAME

# serve
podman run --rm \
  --volume="$BUILD_DIRNAME:/srv/jekyll_build" \
  --volume="$CONTENT_DIR:/srv/jekyll" \
  --name $CONTAINER_NAME \
  -p 8777:4000 \
  -it registry.hub.docker.com/jekyll/jekyll:latest \
  jekyll serve  --destination /srv/jekyll_build --disable-disk-cache --drafts