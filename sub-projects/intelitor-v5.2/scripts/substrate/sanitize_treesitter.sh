#!/bin/bash
# =============================================================================
# sanitize_treesitter.sh - Tree-sitter Substrate Sanitization
# =============================================================================
# Purpose: Prunes stale Tree-sitter caches to resolve nvim parse failures.
# STAMP: SC-SYS-002
# =============================================================================

echo "🧹 [SUBSTRATE] Sanitizing Tree-sitter cache..."

# 1. Prune local nvim state
rm -rf ~/.local/share/nvim/site/pack/packer/start/nvim-treesitter/parser/*
rm -rf ~/.cache/nvim/treesitter/*

# 2. Re-install grammars via nvim (if in interactive mode)
# nvim --headless +TSUpdate +qa

echo "✅ [SUBSTRATE] Tree-sitter sanitization complete."
