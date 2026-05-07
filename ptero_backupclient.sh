#!/bin/bash
# Pterodactyl Wings - Backup dữ liệu server của client

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DATE=$(date +%Y-%m-%d_%H-%M-%S)
VOLUMES_DIR="/var/lib/pterodactyl/volumes"
BACKUP_ROOT="/root/ptero-client-backups"
BACKUP_DIR="$BACKUP_ROOT/$DATE"
KEEP_DAYS=3
LOG_FILE="$BACKUP_DIR/backup.log"

[ "$EUID" -ne 0 ] && echo -e "${RED}❌ Cần quyền root!${NC}" && exit 1
[ ! -d "$VOLUMES_DIR" ] && echo -e "${RED}❌ Không tìm thấy $VOLUMES_DIR${NC}" && exit 1

mkdir -p "$BACKUP_DIR"

log() { echo -e "$1" | tee -a "$LOG_FILE"; }

log "${CYAN}🦕 Wings Client Backup — $DATE${NC}\n"

# Lấy danh sách UUID server
mapfile -t SERVERS < <(ls -1 "$VOLUMES_DIR" 2>/dev/null)

if [ ${#SERVERS[@]} -eq 0 ]; then
    log "${YELLOW}⚠️  Không có server nào trong $VOLUMES_DIR${NC}"
    exit 0
fi

log "📋 Tìm thấy ${#SERVERS[@]} server(s)\n"

SUCCESS=0; FAILED=0; SKIPPED=0

for UUID in "${SERVERS[@]}"; do
    SRC="$VOLUMES_DIR/$UUID"
    OUT="$BACKUP_DIR/${UUID}.tar.gz"

    # Bỏ qua nếu thư mục rỗng
    if [ -z "$(ls -A "$SRC" 2>/dev/null)" ]; then
        log "${YELLOW}⏭️  [$UUID] Thư mục rỗng, bỏ qua.${NC}"
        ((SKIPPED++)); continue
    fi

    SIZE_BEFORE=$(du -sh "$SRC" 2>/dev/null | cut -f1)
    log "${CYAN}📦 [$UUID] Đang nén... (${SIZE_BEFORE})${NC}"

    # Nén với gzip, giữ nguyên cấu trúc thư mục
    if tar -czf "$OUT" -C "$VOLUMES_DIR" "$UUID" 2>>"$LOG_FILE"; then
        SIZE_AFTER=$(du -sh "$OUT" 2>/dev/null | cut -f1)
        log "${GREEN}✅ [$UUID] Xong → ${UUID}.tar.gz (${SIZE_AFTER})${NC}"
        ((SUCCESS++))
    else
        log "${RED}❌ [$UUID] Nén thất bại!${NC}"
        rm -f "$OUT"
        ((FAILED++))
    fi
done

# Ghi file manifest — danh sách UUID đã backup
MANIFEST="$BACKUP_DIR/manifest.txt"
echo "Backup date : $DATE"          > "$MANIFEST"
echo "Total       : ${#SERVERS[@]}" >> "$MANIFEST"
echo "Success     : $SUCCESS"       >> "$MANIFEST"
echo "Failed      : $FAILED"        >> "$MANIFEST"
echo "Skipped     : $SKIPPED"       >> "$MANIFEST"
echo ""                             >> "$MANIFEST"
echo "=== Server UUIDs ===" >> "$MANIFEST"
for UUID in "${SERVERS[@]}"; do
    STATUS="OK"
    [ ! -f "$BACKUP_DIR/${UUID}.tar.gz" ] && STATUS="FAILED/SKIPPED"
    SIZE=$(du -sh "$BACKUP_DIR/${UUID}.tar.gz" 2>/dev/null | cut -f1 || echo "-")
    echo "  $UUID  [$STATUS]  $SIZE" >> "$MANIFEST"
done

# Tổng dung lượng backup lần này
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)

log "\n──────────────────────────────────────"
log "✅ Thành công : $SUCCESS server(s)"
log "❌ Thất bại   : $FAILED server(s)"
log "⏭️  Bỏ qua    : $SKIPPED server(s)"
log "📦 Tổng dung lượng : $TOTAL_SIZE"
log "📂 Lưu tại   : $BACKUP_DIR"
log "📄 Manifest  : $MANIFEST"

# Xóa backup cũ hơn KEEP_DAYS ngày
log "\n${CYAN}🧹 Xóa backup cũ hơn $KEEP_DAYS ngày...${NC}"
find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +$KEEP_DAYS -exec rm -rf {} \;
log "${GREEN}✅ Đã dọn dẹp xong.${NC}"

log "\n${GREEN}🎉 Backup hoàn tất!${NC}"
