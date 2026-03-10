#!/bin/bash
set -euo pipefail

VERSION="${1:-1.0.0}"
OUTPUT_DIR="/tmp/pagorapay_release_$VERSION"
PACKAGE="pagorapay_files_v${VERSION}.tar.gz"
MK_DIR="/opt/mk-auth"
ADDON_DIR="$MK_DIR/admin/addons/pagorapay"

echo "==> Empacotando PagoraPay v$VERSION..."

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/opt/mk-auth/admin/addons/pagorapay"
mkdir -p "$OUTPUT_DIR/opt/mk-auth/admin/addons"
mkdir -p "$OUTPUT_DIR/opt/mk-auth/boleto"
mkdir -p "$OUTPUT_DIR/opt/mk-auth/central"

rsync -a --exclude='pagorapay_config.json' \
    --exclude='.version' --exclude='.install_date' --exclude='.update_date' \
    "$ADDON_DIR/" \
    "$OUTPUT_DIR/opt/mk-auth/admin/addons/pagorapay/"

cp "$MK_DIR/boleto/boleto_pp.php"          "$OUTPUT_DIR/opt/mk-auth/boleto/"
cp "$MK_DIR/boleto/carne_pp.php"           "$OUTPUT_DIR/opt/mk-auth/boleto/"
cp "$MK_DIR/central/prepara_boleto_pp.php" "$OUTPUT_DIR/opt/mk-auth/central/"
cp "$MK_DIR/central/prepara_carne_pp.php"  "$OUTPUT_DIR/opt/mk-auth/central/"

cd "$OUTPUT_DIR"
tar czf "/tmp/$PACKAGE" opt/
echo "$VERSION" > "/tmp/version.txt"

echo ""
echo "==> Pacote gerado:"
ls -lh "/tmp/$PACKAGE"
echo "MD5: $(md5sum /tmp/$PACKAGE)"
echo ""
echo "Faça upload:"
echo "  scp /tmp/$PACKAGE    usuario@SEU_SERVIDOR:/var/www/pagorapay/releases/$VERSION/"
echo "  scp /tmp/version.txt usuario@SEU_SERVIDOR:/var/www/pagorapay/"

rm -rf "$OUTPUT_DIR"
