#!/bin/bash
if [ -z "$HEDDLE_EXT_DIR" ]; then
  PROJECT=heddle
  IMAGE_SCRIPTS_DIR=../../../image_scripts
  RUNTIME_SCRIPTS_DIR=../../../../runtime_scripts
  cd "$(dirname "$0")"
else
  PROJECT="$(basename "$HEDDLE_EXT_DIR")"
  HEDDLE_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
  IMAGE_SCRIPTS_DIR="$HEDDLE_DIR/image_scripts"
  RUNTIME_SCRIPTS_DIR="$HEDDLE_DIR/runtime_scripts"
  mkdir -p "$HEDDLE_EXT_DIR/gen"
  cd "$HEDDLE_EXT_DIR/gen"
fi
ARCH="${1:-x86_64}"
mkdir -p "$ARCH"{,/images,/dist{,/update}}
cat > "$ARCH/images/.gitignore" << 'EOF'
*.img
*.qcow2
*.kbin
EOF
ln -sf "$IMAGE_SCRIPTS_DIR/boot_heddle.sh" "$ARCH/dist/boot_$PROJECT.sh"
ln -sf "$IMAGE_SCRIPTS_DIR/in_heddle.sh" "$ARCH/dist/in_$PROJECT.sh"
ln -sf "$IMAGE_SCRIPTS_DIR/_in_heddle.sh" "$ARCH/dist/_in_$PROJECT.sh"
ln -sf ../images/heddle.img "$ARCH/dist/$PROJECT.img"
ln -sf "$RUNTIME_SCRIPTS_DIR"/init{,2}.sh "$ARCH/dist/update"
