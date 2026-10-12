#!/usr/bin/env bash
# ktogler - Build script
# Thin wrapper around the Makefile build system.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
    echo -e "${GREEN}ktogler Build Script${NC}"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build       - Build the package"
    echo "  install     - Build and install"
    echo "  reinstall   - Uninstall, build, and install"
    echo "  clean       - Remove build artifacts"
    echo "  dev         - Full development cycle"
    echo "  help        - Show this help"
    echo ""
    exit 0
}

case "${1:-build}" in
build)
    make build
    ;;
install)
    make install
    ;;
reinstall)
    make reinstall
    ;;
clean)
    make clean
    ;;
dev)
    make dev
    ;;
help | --help | -h)
    usage
    ;;
*)
    echo -e "${RED}Unknown command: $1${NC}"
    echo ""
    usage
    ;;
esac