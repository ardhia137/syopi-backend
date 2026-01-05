#!/bin/bash

echo "🚀 Building Laravel Docker Staging..."
echo ""

# Create docker directory if not exists
mkdir -p docker

# Copy nginx config to docker directory if not exists
if [ ! -f "docker/nginx.conf" ]; then
    echo "⚠️  nginx.conf not found in docker/ directory"
    exit 1
fi

# Check if .env.docker exists
if [ ! -f ".env.docker" ]; then
    echo "⚠️  .env.docker not found! Please create it first."
    exit 1
fi

# Stop existing container
echo "🛑 Stopping existing container..."
docker-compose down

# Clean up old build artifacts di host (optional)
echo "🧹 Cleaning old build artifacts..."
rm -rf public/build 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true

# Build and start
echo "🔨 Building Docker image..."
docker-compose build --no-cache

echo "🚀 Starting container..."
docker-compose up -d

echo "⏳ Waiting for container to be ready..."
sleep 8

echo ""
echo "🔑 Generating APP_KEY if needed..."
docker exec laravel_staging php artisan key:generate --force

echo ""
echo "📦 Building Vite assets..."
docker exec laravel_staging npm run build

# Remove hot file to prevent Vite dev server detection
echo "🗑️  Removing hot file..."
docker exec laravel_staging rm -f /var/www/public/hot

echo ""
echo "🧹 Clearing Laravel cache after build..."
docker exec laravel_staging php artisan optimize:clear
docker exec laravel_staging php artisan config:cache
docker exec laravel_staging php artisan route:cache
docker exec laravel_staging php artisan view:cache

echo ""
echo "✅ Verifying manifest.json..."
if docker exec laravel_staging test -f /var/www/public/build/manifest.json; then
    echo "✅ manifest.json found!"
    echo "📄 Manifest content:"
    docker exec laravel_staging cat /var/www/public/build/manifest.json
    echo ""
    echo "📂 Build directory contents:"
    docker exec laravel_staging ls -la /var/www/public/build/
else
    echo "⚠️  manifest.json not found, retrying build..."
    docker exec laravel_staging npm install
    docker exec laravel_staging npm run build
fi

echo ""
echo "🔧 Fixing permissions..."
docker exec laravel_staging chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache /var/www/public/build 2>/dev/null || true
docker exec laravel_staging chmod -R 775 /var/www/storage /var/www/bootstrap/cache

echo ""
echo "🔍 Verifying hot file is removed..."
if docker exec laravel_staging test -f /var/www/public/hot; then
    echo "⚠️  WARNING: hot file still exists! Removing it..."
    docker exec laravel_staging rm -f /var/www/public/hot
else
    echo "✅ No hot file found (correct for production)"
fi

echo ""
echo "🔄 Final cache refresh for production..."
docker exec laravel_staging php artisan optimize:clear
docker exec laravel_staging php artisan config:cache
docker exec laravel_staging php artisan route:cache
docker exec laravel_staging php artisan view:cache

echo ""
echo "🔄 Final restart..."
docker-compose restart

echo ""
echo "⏳ Waiting for final startup..."
sleep 5

echo ""
echo "=========================================="
echo "✅ Laravel staging is ready!"
echo "=========================================="
echo ""
echo "📍 Access URL:"
echo "   Local:     http://localhost:4567"
echo "   Tailscale: http://YOUR_TAILSCALE_IP:4567"
echo ""
echo "📊 Useful commands:"
echo "   Logs:      docker-compose logs -f"
echo "   Enter:     docker exec -it laravel_staging bash"
echo "   Rebuild:   ./build.sh"
echo "   Stop:      docker-compose down"
echo ""
echo "🗄️  Database Configuration:"
echo "   Host: host.docker.internal"
echo "   Update credentials in .env.docker before build"
echo ""