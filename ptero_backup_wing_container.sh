#!/bin/bash
# Pterodactyl Wings - Restore dữ liệu server + Wings config

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

BACKUP_ROOT="/root/ptero-client-backups"
VOLUMES_DIR="/var/lib/pterodactyl/volumes"

[ "$EUID" -ne 0 ] && echo -e "${RED}❌ Cần quyền root!${NC}" && exit 1

echo -e "${CYAN}🦕 Wings Client Restore Script${NC}\n"

# ── Chọn bản backup ─────────────────────────────────────────
mapfile -t DIRS < <(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort -r)
[ ${#DIRS[@]} -eq 0 ] && echo -e "${RED}❌ Không có bản backup nào trong $BACKUP_ROOT${NC}" && exit 1

echo -e "${CYAN}📂 Danh sách bản backup:${NC}"
for i in "${!DIRS[@]}"; do
    DIR="${DIRS[$i]}"
    SERVER_COUNT=$(ls -1 "$DIR"*.tar.gz 2>/dev/null | wc -l)
    HAS_CONFIG=""
    [ -f "${DIR}wings-config.yml" ] && HAS_CONFIG=" [wings-config.yml]"
    echo -e "  ${GREEN}[$((i+1))]${NC} $(basename "$DIR") → $SERVER_COUNT server(s)$HAS_CONFIG"
done
read -rp "Chọn bản backup (1-${#DIRS[@]}): " C
[[ ! "$C" =~ ^[0-9]+$ ]] || [ "$C" -lt 1 ] || [ "$C" -gt "${#DIRS[@]}" ] && echo -e "${RED}❌ Không hợp lệ${NC}" && exit 1
SELECTED="${DIRS[$((C-1))]}"

# ── Chọn restore Wings config ───────────────────────────────
RESTORE_CONFIG=0
if [ -f "${SELECTED}wings-config.yml" ]; then
    read -rp "❓ Restore Wings config.yml? (yes/no): " RC
    [ "$RC" = "yes" ] && RESTORE_CONFIG=1
else
    echo -e "${YELLOW}⚠️  Không có wings-config.yml trong bản này.${NC}"
fi

# ── Chọn server UUID cần restore ────────────────────────────
mapfile -t TAR_FILES < <(ls -1 "$SELECTED"*.tar.gz 2>/dev/null)

RESTORE_ALL=0
SELECTED_UUIDS=()

if [ ${#TAR_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Không có file server nào trong bản backup này.${NC}"
else
    echo -e "\n${CYAN}📦 Danh sách server trong bản backup:${NC}"
    for i in "${!TAR_FILES[@]}"; do
        UUID=$(basename "${TAR_FILES[$i]}" .tar.gz)
        SIZE=$(du -sh "${TAR_FILES[$i]}" 2>/dev/null | cut -f1)
        EXISTS=""
        [ -d "$VOLUMES_DIR/$UUID" ] && EXISTS="${YELLOW}(đang tồn tại)${NC}"
        echo -e "  ${GREEN}[$((i+1))]${NC} $UUID  $SIZE  $EXISTS"
    done
    echo -e "  ${CYAN}[A]${NC} Restore tất cả"
    echo -e "  ${YELLOW}[0]${NC} Bỏ qua"

    read -rp "Chọn server (0/A/1-${#TAR_FILES[@]}): " S

    if [ "$S" = "A" ] || [ "$S" = "a" ]; then
        RESTORE_ALL=1
    elif [ "$S" = "0" ]; then
        echo -e "${YELLOW}⏭️  Bỏ qua restore server data.${NC}"
    elif [[ "$S" =~ ^[0-9]+$ ]] && [ "$S" -ge 1 ] && [ "$S" -le "${#TAR_FILES[@]}" ]; then
        SELECTED_UUIDS+=("$(basename "${TAR_FILES[$((S-1))]}" .tar.gz)")
    else
        echo -e "${RED}❌ Không hợp lệ${NC}" && exit 1
    fi
fi

# ── Xác nhận ────────────────────────────────────────────────
echo -e "\n${YELLOW}⚠️  Hành động này sẽ ghi đè dữ liệu hiện tại!${NC}"
echo -e "  Bản backup : ${CYAN}$(basename "$SELECTED")${NC}"
[ "$RESTORE_CONFIG" = "1" ]  && echo -e "  Config     : ${CYAN}wings-config.yml${NC}"
[ "$RESTORE_ALL" = "1" ]     && echo -e "  Server     : ${CYAN}Tất cả (${#TAR_FILES[@]} server)${NC}"
[ ${#SELECTED_UUIDS[@]} -gt 0 ] && echo -e "  Server     : ${CYAN}${SELECTED_UUIDS[*]}${NC}"
read -rp "Tiếp tục? (yes/no): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo -e "${RED}🚫 Đã hủy.${NC}" && exit 0

safe_bak() { [ -e "$1" ] && cp -r "$1" "${1}.bak_$(date +%Y%m%d_%H%M%S)" && echo -e "  ${YELLOW}⚠️  Đã lưu bản gốc: $1.bak_*${NC}"; }

echo ""

# ── 1. Restore Wings config ─────────────────────────────────
if [ "$RESTORE_CONFIG" = "1" ]; then
    safe_bak /etc/pterodactyl/config.yml
    mkdir -p /etc/pterodactyl
    cp "${SELECTED}wings-config.yml" /etc/pterodactyl/config.yml
    chmod 644 /etc/pterodactyl/config.yml
    echo -e "${GREEN}✅ Restored wings-config.yml${NC}"
fi

# ── 2. Restore server volumes ───────────────────────────────
do_restore() {
    local UUID="$1"
    local TAR="$SELECTED${UUID}.tar.gz"

    [ ! -f "$TAR" ] && echo -e "${RED}❌ [$UUID] Không tìm thấy file tar!${NC}" && return

    safe_bak "$VOLUMES_DIR/$UUID"
    rm -rf "$VOLUMES_DIR/$UUID"
    mkdir -p "$VOLUMES_DIR"

    if tar -xzf "$TAR" -C "$VOLUMES_DIR" 2>/dev/null; then
        chown -R pterodactyl:pterodactyl "$VOLUMES_DIR/$UUID" 2>/dev/null || true
        echo -e "${GREEN}✅ [$UUID] Restored xong.${NC}"
    else
        echo -e "${RED}❌ [$UUID] Giải nén thất bại!${NC}"
    fi
}

if [ "$RESTORE_ALL" = "1" ]; then
    for TAR in "${TAR_FILES[@]}"; do
        do_restore "$(basename "$TAR" .tar.gz)"
    done
elif [ ${#SELECTED_UUIDS[@]} -gt 0 ]; then
    for UUID in "${SELECTED_UUIDS[@]}"; do
        do_restore "$UUID"
    done
fi

# ── 3. Restart Wings ────────────────────────────────────────
echo ""
if systemctl is-active --quiet wings; then
    systemctl restart wings && echo -e "${GREEN}✅ Đã restart Wings${NC}"
else
    echo -e "${YELLOW}⚠️  Wings không chạy, bỏ qua restart.${NC}"
fi

echo -e "\n${GREEN}🎉 Restore hoàn tất!${NC}"
echo -e "${YELLOW}💡 Bản gốc được lưu với đuôi .bak_* nếu bị ghi đè.${NC}"
