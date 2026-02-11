# =====================================================
# Vim configuratie
# =====================================================
VIMRC_SOURCE="$STACK_DIR/files/.vimrc"
VIMRC_DEST="/home/$SUDO_USER/.vimrc"

if [ -f "$VIMRC_SOURCE" ]; then
    echo "📄 Kopieer .vimrc naar $VIMRC_DEST"
    cp "$VIMRC_SOURCE" "$VIMRC_DEST"
    chown $SUDO_USER:$SUDO_USER "$VIMRC_DEST"
    chmod 644 "$VIMRC_DEST"
else
    echo "⚠️ .vimrc bronbestand niet gevonden: $VIMRC_SOURCE"
fi