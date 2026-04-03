#!/bin/bash

# Setup Gemini CLI for easy command line access

echo "🤖 Setting up Gemini CLI..."

# Source the gemini function into current shell
source ./scripts/ai/gemini_cli.sh

echo "✅ Gemini CLI loaded in current session!"
echo ""
echo "📋 Usage:"
echo "  gemini hello world"
echo "  gemini \"explain quantum computing\""
echo "  gemini help me debug this elixir code"
echo ""
echo "🔑 Setup API Key:"
echo "  1. Get key from: https://makersuite.google.com/app/apikey"
echo "  2. Run: export GOOGLE_API_KEY='your-key-here'"
echo ""
echo "💡 To make it permanent, add to ~/.bashrc:"
echo "  echo 'source $(pwd)/scripts/ai/gemini_cli.sh' >> ~/.bashrc"
echo "  echo 'export GOOGLE_API_KEY=\"your-key\"' >> ~/.bashrc"