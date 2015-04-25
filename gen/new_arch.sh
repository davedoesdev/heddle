#!/bin/bash
cd "$(dirname "$0")"
ARCH="$1"
mkdir -p "$ARCH"{,/images,/dist{,/update}}
cat > "$ARCH/images/.gitignore" << 'EOF'
*.img
*.qcow2
EOF
ln -sf ../../../image_scripts/boot_heddle.sh ../images/heddle.img "$ARCH/dist"
ln -sf ../../../../runtime_scripts/init{,2}.sh "$ARCH/dist/update"
