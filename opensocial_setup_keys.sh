#!/bin/bash

# OpenSocial OAuth2 Key Setup Script
# This script generates the required OAuth2 keys for the Simple OAuth module

set -e

echo "=================================="
echo "OpenSocial OAuth2 Key Setup"
echo "=================================="
echo ""

# Get the Drupal root directory
read -p "Enter the path to your OpenSocial/Drupal installation: " DRUPAL_ROOT

if [ ! -d "$DRUPAL_ROOT" ]; then
    echo "Error: Directory $DRUPAL_ROOT does not exist!"
    exit 1
fi

# Create keys directory
KEYS_DIR="$DRUPAL_ROOT/keys"
echo "Creating keys directory at $KEYS_DIR..."
mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"

# Generate private key
echo "Generating private key..."
openssl genrsa -out "$KEYS_DIR/private.key" 2048

# Generate public key
echo "Generating public key..."
openssl rsa -in "$KEYS_DIR/private.key" -pubout -out "$KEYS_DIR/public.key"

# Set permissions
echo "Setting file permissions..."
chmod 600 "$KEYS_DIR/private.key"
chmod 644 "$KEYS_DIR/public.key"

# Get the web server user
read -p "Enter your web server user (e.g., www-data, apache, nginx): " WEB_USER

if id "$WEB_USER" >/dev/null 2>&1; then
    echo "Setting ownership to $WEB_USER..."
    chown -R "$WEB_USER:$WEB_USER" "$KEYS_DIR"
else
    echo "Warning: User $WEB_USER not found. Please set ownership manually."
fi

echo ""
echo "=================================="
echo "Keys generated successfully!"
echo "=================================="
echo ""
echo "Private key: $KEYS_DIR/private.key"
echo "Public key:  $KEYS_DIR/public.key"
echo ""
echo "Next steps:"
echo "1. Configure Simple OAuth in Drupal:"
echo "   - Navigate to: Configuration > People > Simple OAuth"
echo "   - Set Public Key path: $KEYS_DIR/public.key"
echo "   - Set Private Key path: $KEYS_DIR/private.key"
echo ""
echo "2. Create an OAuth2 Client:"
echo "   - Navigate to: Configuration > People > Simple OAuth > OAuth2 Clients"
echo "   - Click 'Add OAuth2 Client'"
echo "   - Note the Client ID and Client Secret for Moodle configuration"
echo ""
echo "3. Install the OpenSocial OAuth Provider module"
echo ""
