#!/bin/bash
# Pterodactyl Restore Script

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

CONFIG_ROOT="/root/ptero-backups"
DATA_ROOT="/root/backup_containter+data"
BACKUP_DEST="/var/lib/pterodactyl/backups"

[ "$EUID" -ne 0 ] && echo -e "${RED}❌ Cần quyền root!${NC}" && exit 1

echo -e "${CYAN}🦕 Pterodactyl Restore Script${NC}\n"

# Chọn bản backup config
mapfile -t DIRS < <(ls -1d "$CONFIG_ROOT"/*/ 2>/dev/null | sort -r)
[ ${#DIRS[@]} -eq 0 ] && echo -e "${RED}❌ Không có backup config!${NC}" && exit 1

echo -e "${CYAN}📂 Backup config:${NC}"
for i in "${!DIRS[@]}"; do
    FILES=""
    [ -f "${DIRS[$i]}panel.env" ]        && FILES+="[panel.env] "
    [ -f "${DIRS[$i]}wings-config.yml" ] && FILES+="[wings-config.yml]"
    echo -e "  ${GREEN}[$((i+1))]${NC} $(basename "${DIRS[$i]}") → $FILES"
done
read -rp "Chọn (1-${#DIRS[@]}): " C
[[ ! "$C" =~ ^[0-9]+$ ]] || [ "$C" -lt 1 ] || [ "$C" -gt "${#DIRS[@]}" ] && echo -e "${RED}❌ Không hợp lệ${NC}" && exit 1
SELECTED_DIR="${DIRS[$((C-1))]}"

# Chọn bản backup container data
echo -e "\n${CYAN}📦 Backup container data:${NC}"
mapfile -t DATA_DIRS < <(ls -1d "$DATA_ROOT"/*/ 2>/dev/null | sort -r)
if [ ${#DATA_DIRS[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️ Không có backup container.${NC}"
    SELECTED_DATA=""
else
    for i in "${!DATA_DIRS[@]}"; do
        COUNT=$(ls -1 "${DATA_DIRS[$i]}"*.tar.gz 2>/dev/null | wc -l)
        SIZE=$(du -sh "${DATA_DIRS[$i]}" 2>/dev/null | cut -f1)
        echo -e "  ${GREEN}[$((i+1))]${NC} $(basename "${DATA_DIRS[$i]}") → $COUNT file, $SIZE"
    done
    echo -e "  ${YELLOW}[0]${NC} Bỏ qua"
    read -rp "Chọn (0-${#DATA_DIRS[@]}): " D
    if [ "$D" = "0" ]; then
        SELECTED_DATA=""
    elif [[ ! "$D" =~ ^[0-9]+$ ]] || [ "$D" -lt 1 ] || [ "$D" -gt "${#DATA_DIRS[@]}" ]; then
        echo -e "${RED}❌ Không hợp lệ${NC}" && exit 1
    else
        SELECTED_DATA="${DATA_DIRS[$((D-1))]}"
    fi
fi

# Xác nhận
echo -e "\n${YELLOW}⚠️  Sẽ ghi đè file hiện tại!${NC}"
echo -e "  Config : $(basename "$SELECTED_DIR")"
[ -n "$SELECTED_DATA" ] && echo -e "  Data   : $(basename "$SELECTED_DATA")"
read -rp "Tiếp tục? (yes/no): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo -e "${RED}🚫 Đã hủy.${NC}" && exit 0

safe_bak() { [ -f "$1" ] && cp "$1" "${1}.bak_$(date +%Y%m%d_%H%M%S)" && echo -e "  ${YELLOW}⚠️ Đã lưu bản gốc: $1.bak_*${NC}"; }

# Restore panel .env
if [ -f "$SELECTED_DIR/panel.env" ]; then
    safe_bak /var/www/pterodactyl/.env
    cp "$SELECTED_DIR/panel.env" /var/www/pterodactyl/.env
    chown www-data:www-data /var/www/pterodactyl/.env && chmod 640 /var/www/pterodactyl/.env
    echo -e "${GREEN}✅ Restored panel.env${NC}"
else
    echo -e "${YELLOW}⚠️ Không có panel.env, bỏ qua.${NC}"
fi

# Restore Wings config
if [ -f "$SELECTED_DIR/wings-config.yml" ]; then
    safe_bak /etc/pterodactyl/config.yml
    mkdir -p /etc/pterodactyl
    cp "$SELECTED_DIR/wings-config.yml" /etc/pterodactyl/config.yml && chmod 644 /etc/pterodactyl/config.yml
    echo -e "${GREEN}✅ Restored wings config.yml${NC}"
else
    echo -e "${YELLOW}⚠️ Không có wings-config.yml, bỏ qua.${NC}"
fi

# Restore container .tar.gz
if [ -n "$SELECTED_DATA" ]; then
    TAR_FILES=("$SELECTED_DATA"*.tar.gz)
    if [ -e "${TAR_FILES[0]}" ]; then
        mkdir -p "$BACKUP_DEST"
        cp -v "$SELECTED_DATA"*.tar.gz "$BACKUP_DEST/"
        chown -R pterodactyl:pterodactyl "$BACKUP_DEST" 2>/dev/null || true
        echo -e "${GREEN}✅ Restored $(ls -1 "$SELECTED_DATA"*.tar.gz | wc -l) file .tar.gz${NC}"
    else
        echo -e "${YELLOW}⚠️ Không có file .tar.gz, bỏ qua.${NC}"
    fi
fi

# Restart services
echo -e "\n${CYAN}🔁 Restart services...${NC}"
for SVC in wings pteroq nginx apache2; do
    if systemctl is-active --quiet "$SVC"; then
        systemctl restart "$SVC" && echo -e "${GREEN}✅ Restarted $SVC${NC}"
    fi
done

echo -e "\n${GREEN}✅ Restore hoàn tất!${NC}"
echo -e "${YELLOW}💡 File gốc được lưu với đuôi .bak_* nếu bị ghi đè.${NC}"
