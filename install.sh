#!/bin/bash
# =============================================================================
#  PagoraPay para MKAuth — Instalador v1.0.0
# =============================================================================
set -euo pipefail

GITHUB_TOKEN="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"
GITHUB_RAW="https://raw.githubusercontent.com/PagoraPay/mkauth-addon/main"
GITHUB_PKG="https://github.com/PagoraPay/mkauth-addon/raw/main/pagorapay_files_v1.0.0.tar.gz"
PP_VERSION="1.0.0"
MK_DIR="/opt/mk-auth"
ADDON_DIR="$MK_DIR/admin/addons/pagorapay"
BACKUP_DIR="/opt/pagorapay_backup_$(date +%Y%m%d_%H%M%S)"
LOG="/var/log/pagorapay_install.log"

# ── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Funções visuais ───────────────────────────────────────────────────────────
step_ok()   { echo -e "  ${GREEN}✔${NC}  $*" | tee -a "$LOG"; }
step_warn() { echo -e "  ${YELLOW}⚠${NC}  $*" | tee -a "$LOG"; }
step_err()  { echo -e "  ${RED}✖${NC}  $*" | tee -a "$LOG"; exit 1; }
step_run()  { echo -e "  ${CYAN}►${NC}  $*" | tee -a "$LOG"; }

progress_bar() {
    local label="$1" total=20
    echo -ne "  ${CYAN}►${NC}  $label "
    for i in $(seq 1 $total); do
        echo -ne "${GREEN}█${NC}"
        sleep 0.04
    done
    echo -e "  ${GREEN}✔${NC}"
}

draw_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "  +======================================================+"
    echo "  |                                                      |"
    echo "  |   ____   _    ____  ___  ____   _    ____  _   _    |"
    echo "  |  |  _ \ / \  / ___|/ _ \|  _ \ / \  |  _ \| \ | |  |"
    echo "  |  | |_) / _ \| |  _| | | | |_) / _ \ | |_) |  \| |  |"
    echo "  |  |  __/ ___ \ |_| | |_| |  _ < ___ \|  __/| |\  |  |"
    echo "  |  |_| /_/   \_\____|\___/|_| \_\  _/ |_|   |_| \_|  |"
    echo "  |                    ____  __ _   _   _                |"
    echo "  |                   |  _ \|  _ \ | \ | |              |"
    echo "  |                   | |_) | |_) ||  \| |              |"
    echo "  |                   |  __/|  _ < | |\  |              |"
    echo "  |                   |_|   |_| \_\|_| \_|              |"
    echo "  |                                                      |"
    echo "  |        Addon para MKAuth --- Boleto & PIX            |"
    echo "  ║                                                      ║"





    echo "  ║        ╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ║"
    echo "  ║                                                      ║"
    echo "  ║          Addon para MKAuth — Boleto & PIX            ║"
    echo -e "  ║              ${YELLOW}Versão $PP_VERSION${BLUE}                              ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

draw_status() {
    local step="$1" total="$2" label="$3"
    echo -e "  ${BOLD}Etapa $step de $total:${NC} $label"
    echo ""
}

draw_footer_success() {
    echo ""
    echo -e "${BOLD}${GREEN}"

    echo "  ║                                                      ║"
    echo "  ║        ✔  PagoraPay instalado com sucesso!          ║"
    echo "  ║                                                      ║"
    echo "  ╠══════════════════════════════════════════════════════╣"
    echo -e "  ║  ${NC}${BOLD}Próximos passos:${GREEN}                                    ║"
    echo "  ║                                                      ║"
    echo "  ║  1. Acesse MKAuth → menu PagoraPay                   ║"
    echo "  ║  2. Configure sua API key                            ║"
    echo "  ║  3. Teste um boleto pela Central do Assinante        ║"
    echo "  ║                                                      ║"
    echo -e "  ║  ${NC}Log: /var/log/pagorapay_install.log${GREEN}               ║"
    echo "  ║                                                      ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ── Início ────────────────────────────────────────────────────────────────────
draw_header
date >> "$LOG"

# ── Etapa 1: Pré-requisitos ───────────────────────────────────────────────────
draw_status 1 7 "Verificando pré-requisitos"

[[ $EUID -ne 0 ]] && step_err "Execute como root (sudo ou su -)"
step_ok "Executando como root"

[[ -d "$MK_DIR" ]] || step_err "MKAuth não encontrado em $MK_DIR"
step_ok "MKAuth encontrado em $MK_DIR"

for cmd in php mysql curl tar apparmor_parser crontab; do
    command -v "$cmd" &>/dev/null && step_ok "$cmd disponível" || step_err "$cmd não encontrado"
done

mysql -uroot -pvertrigo mkradius -e "SELECT 1" &>/dev/null \
    && step_ok "MySQL OK" || step_err "Falha ao conectar ao MySQL"

echo ""

# ── Etapa 2: Backup ───────────────────────────────────────────────────────────
draw_status 2 7 "Realizando backup"
mkdir -p "$BACKUP_DIR"
for f in "$MK_DIR/boleto/.htaccess" "$MK_DIR/central/.htaccess" \
          "$MK_DIR/admin/addons/addons.js" "/etc/apparmor.d/sistema.php-central"; do
    [[ -f "$f" ]] && cp "$f" "$BACKUP_DIR/" && step_ok "Backup: $(basename $f)"
done
[[ -d "$ADDON_DIR" ]] && cp -r "$ADDON_DIR" "$BACKUP_DIR/pagorapay_addon"
step_ok "Backup salvo em $BACKUP_DIR"
echo ""

# ── Etapa 3: Download ─────────────────────────────────────────────────────────
draw_status 3 7 "Baixando arquivos do addon"
TMP_PKG="/tmp/pagorapay_install_$$.tar.gz"
TMP_EXTRACT="/tmp/pagorapay_extract_$$"

step_run "Conectando ao repositório..."
curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_PKG" -o "$TMP_PKG" \
    || step_err "Falha ao baixar pacote. Verifique sua conexão."

progress_bar "Baixando pacote"
step_ok "Pacote baixado: $(du -sh $TMP_PKG | cut -f1)"
echo ""

# ── Etapa 4: Instalação dos arquivos ─────────────────────────────────────────
draw_status 4 7 "Instalando arquivos"
mkdir -p "$TMP_EXTRACT"
tar xzf "$TMP_PKG" -C "$TMP_EXTRACT"

rsync -a --exclude='pagorapay_config.json' \
    "$TMP_EXTRACT/opt/mk-auth/admin/addons/pagorapay/" "$ADDON_DIR/"

for f in boleto_pp.php carne_pp.php; do
    cp "$TMP_EXTRACT/opt/mk-auth/boleto/$f" "$MK_DIR/boleto/"
done
for f in prepara_boleto_pp.php prepara_carne_pp.php; do
    cp "$TMP_EXTRACT/opt/mk-auth/central/$f" "$MK_DIR/central/"
done

chown -R www-data:www-data "$ADDON_DIR"
chmod -R 755 "$ADDON_DIR"
progress_bar "Copiando arquivos"
step_ok "Arquivos instalados"
echo ""

# ── Etapa 5: Configurações do sistema ────────────────────────────────────────
draw_status 5 7 "Configurando sistema"

# addons.js
ADDONS_JS="$MK_DIR/admin/addons/addons.js"
if [[ ! -f "$ADDONS_JS" ]]; then
    echo '$.getScript("/admin/addons/pagorapay/addon.js");' > "$ADDONS_JS"
    chown www-data:www-data "$ADDONS_JS"; chmod 755 "$ADDONS_JS"
    step_ok "addons.js criado"
elif ! grep -q "pagorapay" "$ADDONS_JS"; then
    echo '$.getScript("/admin/addons/pagorapay/addon.js");' >> "$ADDONS_JS"
    step_ok "addons.js atualizado"
else
    step_ok "addons.js já configurado"
fi

# AppArmor
APPARMOR="/etc/apparmor.d/sistema.php-central"
if [[ -f "$APPARMOR" ]] && ! grep -q "pagorapay" "$APPARMOR"; then
    sed -i 's|/opt/mk-auth/admin/arquivos/\*\* rw,|/opt/mk-auth/admin/arquivos/** rw,\n        /opt/mk-auth/admin/addons/pagorapay/** mrwlkix,|' "$APPARMOR"
    apparmor_parser -r "$APPARMOR"
    step_ok "AppArmor configurado"
else
    step_ok "AppArmor já configurado"
fi

# htaccess boleto
HT_BOLETO="$MK_DIR/boleto/.htaccess"
if ! grep -q "pp_bypass" "$HT_BOLETO" 2>/dev/null; then
    sed -i 's/RewriteEngine On/RewriteEngine On\n\n# PagoraPay\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^boleto\\.hhvm$ \/boleto\/boleto_pp.php [QSA,L]\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^carne\\.hhvm$ \/boleto\/carne_pp.php [QSA,L]\n/' "$HT_BOLETO"
    step_ok "htaccess boleto configurado"
else
    step_ok "htaccess boleto já configurado"
fi

# htaccess central
HT_CENTRAL="$MK_DIR/central/.htaccess"
if ! grep -q "prepara_boleto_pp" "$HT_CENTRAL" 2>/dev/null; then
    if grep -q "prepara_boleto" "$HT_CENTRAL"; then
        sed -i '/prepara_boleto/i # PagoraPay\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^prepara_boleto.hhvm$ /central/prepara_boleto_pp.php [QSA,L]\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^prepara_carne.hhvm$ /central/prepara_carne_pp.php [QSA,L]\n' "$HT_CENTRAL"
    else
        sed -i 's/RewriteEngine On/RewriteEngine On\n\n# PagoraPay\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^prepara_boleto.hhvm$ \/central\/prepara_boleto_pp.php [QSA,L]\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^prepara_carne.hhvm$ \/central\/prepara_carne_pp.php [QSA,L]\n/' "$HT_CENTRAL"
    fi
    step_ok "htaccess central configurado"
else
    step_ok "htaccess central já configurado"
fi
echo ""

# ── Etapa 6: Banco de dados e config ──────────────────────────────────────────
draw_status 6 7 "Configurando banco de dados"

mysql -uroot -pvertrigo mkradius 2>/dev/null << 'SQL'
CREATE TABLE IF NOT EXISTS `pagorapay_boletos` (
  `id`              INT AUTO_INCREMENT PRIMARY KEY,
  `titulo_id`       INT NOT NULL,
  `carne_id`        INT DEFAULT NULL,
  `id_externo`      VARCHAR(100) DEFAULT NULL,
  `status`          VARCHAR(30) DEFAULT 'pendente',
  `valor`           DECIMAL(10,2) DEFAULT NULL,
  `vencimento`      DATE DEFAULT NULL,
  `linha_digitavel` VARCHAR(200) DEFAULT NULL,
  `pix_copia_cola`  TEXT DEFAULT NULL,
  `pix_qrcode`      MEDIUMTEXT DEFAULT NULL,
  `boleto_url`      VARCHAR(500) DEFAULT NULL,
  `nosso_numero`    VARCHAR(100) DEFAULT NULL,
  `created_at`      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_titulo (`titulo_id`),
  INDEX idx_carne  (`carne_id`),
  INDEX idx_status (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL
step_ok "Tabela pagorapay_boletos OK"

# Config inicial
CONFIG="$ADDON_DIR/pagorapay_config.json"
if [[ ! -f "$CONFIG" ]] || [[ ! -s "$CONFIG" ]]; then
    NUMCONTA=$(mysql -uroot -pvertrigo mkradius -sNe "SELECT numconta FROM sis_servidores LIMIT 1" 2>/dev/null || echo "1")
    echo ""

    echo -e "  ${BOLD}║     Configure sua API PagoraPay      ║${NC}"
    echo -e "  ${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    read -r -p "  API Key (pp_...): " PP_API_KEY
    read -r -p "  Ambiente [sandbox/producao]: " PP_ENV
    PP_ENV="${PP_ENV:-sandbox}"
    [[ "$PP_ENV" == "producao" ]] && PP_SB="false" && PP_TEST="false" || PP_SB="true" && PP_TEST="true"
    cat > "$CONFIG" << EOF
{
    "api_key": "$PP_API_KEY",
    "teste": $PP_TEST,
    "sandbox": $PP_SB,
    "dias_vencimento": 30,
    "multa": 0,
    "juros": 0,
    "instrucoes": "",
    "webhook_token": "$(openssl rand -hex 16)",
    "numconta": $NUMCONTA
}
EOF
    chown www-data:www-data "$CONFIG"; chmod 660 "$CONFIG"
    step_ok "Configuração salva"
else
    step_ok "Configuração existente mantida"
fi
echo ""

# ── Etapa 7: Cron e Guardian ──────────────────────────────────────────────────
draw_status 7 7 "Instalando cron e proteção guardian"

CRON_LINE='* * * * * for i in $(seq 1 12); do php /opt/mk-auth/admin/addons/pagorapay/cron_boletos.php >> /var/log/pagorapay_cron.log 2>&1; sleep 5; done'
CURRENT_CRON=$(crontab -l 2>/dev/null || true)
if ! echo "$CURRENT_CRON" | grep -q "cron_boletos"; then
    (echo "$CURRENT_CRON"; echo "$CRON_LINE") | crontab -
    step_ok "Cron de boletos instalado"
else
    step_ok "Cron de boletos já existe"
fi

# Guardian
cat > /opt/pagorapay_guardian.sh << 'GUARDIAN'
#!/bin/bash
MK_DIR="/opt/mk-auth"
CHANGED=0

check_and_fix_htaccess() {
    local HT="$1" MARKER="$2" TYPE="$3"
    if [[ -f "$HT" ]] && ! grep -q "$MARKER" "$HT"; then
        echo "[$(date)] Replicando htaccess $TYPE..."
        if [[ "$TYPE" == "boleto" ]]; then
            sed -i 's/RewriteEngine On/RewriteEngine On\n\n# PagoraPay\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^boleto\\.hhvm$ \/boleto\/boleto_pp.php [QSA,L]\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^carne\\.hhvm$ \/boleto\/carne_pp.php [QSA,L]\n/' "$HT"
        else
            sed -i 's/RewriteEngine On/RewriteEngine On\n\n# PagoraPay\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^prepara_boleto.hhvm$ \/central\/prepara_boleto_pp.php [QSA,L]\nRewriteCond %{QUERY_STRING} !pp_bypass=1\nRewriteRule ^prepara_carne.hhvm$ \/central\/prepara_carne_pp.php [QSA,L]\n/' "$HT"
        fi
        CHANGED=1
    fi
}

check_and_fix_htaccess "$MK_DIR/boleto/.htaccess"  "pp_bypass"          "boleto"
check_and_fix_htaccess "$MK_DIR/central/.htaccess" "prepara_boleto_pp"  "central"

if [[ ! -f "$MK_DIR/admin/addons/addons.js" ]] || ! grep -q "pagorapay" "$MK_DIR/admin/addons/addons.js"; then
    echo '$.getScript("/admin/addons/pagorapay/addon.js");' >> "$MK_DIR/admin/addons/addons.js"
    chown www-data:www-data "$MK_DIR/admin/addons/addons.js"
    CHANGED=1
fi

if [[ -f "/etc/apparmor.d/sistema.php-central" ]] && ! grep -q "pagorapay" "/etc/apparmor.d/sistema.php-central"; then
    sed -i 's|/opt/mk-auth/admin/arquivos/\*\* rw,|/opt/mk-auth/admin/arquivos/** rw,\n        /opt/mk-auth/admin/addons/pagorapay/** mrwlkix,|' /etc/apparmor.d/sistema.php-central
    apparmor_parser -r /etc/apparmor.d/sistema.php-central
    CHANGED=1
fi

[[ $CHANGED -eq 1 ]] && echo "[$(date)] Guardian reaplicou configurações" || true
GUARDIAN
chmod +x /opt/pagorapay_guardian.sh

UPDATED_CRON=$(crontab -l 2>/dev/null || true)
if ! echo "$UPDATED_CRON" | grep -q "pagorapay_guardian"; then
    (echo "$UPDATED_CRON"; echo "@reboot /opt/pagorapay_guardian.sh >> /var/log/pagorapay_guardian.log 2>&1"; echo "*/5 * * * * /opt/pagorapay_guardian.sh >> /var/log/pagorapay_guardian.log 2>&1") | crontab -
    step_ok "Guardian instalado"
fi

# Registra versão
echo "$PP_VERSION" > "$ADDON_DIR/.version"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ADDON_DIR/.install_date"
step_ok "Versão $PP_VERSION registrada"

# Limpeza
rm -rf "$TMP_PKG" "$TMP_EXTRACT"

draw_footer_success
