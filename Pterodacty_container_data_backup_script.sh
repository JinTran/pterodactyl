#!/bin/bash
# ==========================================================
# Pterodactyl Selective Backup Script (Config & Container Data)
# Chạy trên máy Panel + Wings (hoặc riêng lẻ)
# ==========================================================

DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="/root/ptero-backups/$DATE"
PTERO_BACKUP_SRC="/var/lib/pterodactyl/backups"
PTERO_BACKUP_DEST="/root/backup_containter+data/$DATE"

mkdir -p "$BACKUP_DIR"
echo "🚀 Bắt đầu backup lúc $DATE"

# ──────────────────────────────────────────────────────────
# 1. Backup file .env (Panel)
# ──────────────────────────────────────────────────────────
if [ -f /var/www/pterodactyl/.env ]; then
    cp /var/www/pterodactyl/.env "$BACKUP_DIR/panel.env"
    echo "✅ Đã backup .env"
fi

# ──────────────────────────────────────────────────────────
# 2. Backup Wings config
# ──────────────────────────────────────────────────────────
if [ -f /etc/pterodactyl/config.yml ]; then
    cp /etc/pterodactyl/config.yml "$BACKUP_DIR/wings-config.yml"
    echo "✅ Đã backup Wings config"
fi

# ──────────────────────────────────────────────────────────
# 3. Copy backup từ Pterodactyl (tab Backups) sang thư mục riêng
# ──────────────────────────────────────────────────────────
if [ -d "$PTERO_BACKUP_SRC" ] && [ "$(ls -A $PTERO_BACKUP_SRC 2>/dev/null)" ]; then
    mkdir -p "$PTERO_BACKUP_DEST"
    cp -v "$PTERO_BACKUP_SRC"/*.tar.gz "$PTERO_BACKUP_DEST/" 2>/dev/null
    
    COPIED=$(ls -1 "$PTERO_BACKUP_DEST" 2>/dev/null | wc -l)
    SIZE=$(du -sh "$PTERO_BACKUP_DEST" 2>/dev/null | cut -f1)
    echo "✅ Đã copy $COPIED file backup container vào: $PTERO_BACKUP_DEST ($SIZE)"
else
    echo "⚠️  Không có file backup nào trong $PTERO_BACKUP_SRC, bỏ qua."
fi

# ──────────────────────────────────────────────────────────
# 4. Xóa backup cũ hơn 3 ngày
# ──────────────────────────────────────────────────────────
find /root/ptero-backups/ -maxdepth 1 -type d -mtime +3 -exec rm -rf {} \;
find /root/backup_containter+data/ -maxdepth 1 -type d -mtime +3 -exec rm -rf {} \;
echo "🧹 Đã dọn dẹp các bản backup cũ hơn 3 ngày."

# ──────────────────────────────────────────────────────────
echo ""
echo "✅ Hoàn tất!"
echo "📂 Config lưu tại: $BACKUP_DIR"
echo "📦 Container backups lưu tại: $PTERO_BACKUP_DEST"
