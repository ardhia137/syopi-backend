#!/bin/bash

echo "🔧 Quick Fix: Force Vite Production Mode"
echo ""

# Remove hot file
echo "1️⃣  Removing hot file..."
docker exec laravel_staging rm -f /var/www/public/hot
if [ $? -eq 0 ]; then
    echo "   ✅ Hot file removed"
else
    echo "   ⚠️  Failed to remove hot file (maybe doesn't exist)"
fi

# Verify manifest exists
echo ""
echo "2️⃣  Checking manifest.json..."
if docker exec laravel_staging test -f /var/www/public/build/manifest.json; then
    echo "   ✅ manifest.json exists"
    docker exec laravel_staging cat /var/www/public/build/manifest.json
else
    echo "   ❌ manifest.json NOT FOUND!"
    echo "   Run ./build.sh to rebuild assets"
    exit 1
fi

# Clear and rebuild cache
echo ""
echo "3️⃣  Rebuilding cache..."
docker exec laravel_staging php artisan optimize:clear
docker exec laravel_staging php artisan config:cache
docker exec laravel_staging php artisan route:cache
docker exec laravel_staging php artisan view:cache
echo "   ✅ Cache rebuilt"

# Verify hot file is still gone
echo ""
echo "4️⃣  Final verification..."
if docker exec laravel_staging test -f /var/www/public/hot; then
    echo "   ❌ WARNING: hot file reappeared!"
    docker exec laravel_staging rm -f /var/www/public/hot
else
    echo "   ✅ No hot file (correct)"
fi

# Check APP_ENV
echo ""
echo "5️⃣  Checking APP_ENV..."
APP_ENV=$(docker exec laravel_staging php artisan tinker --execute="echo config('app.env');")
echo "   Current APP_ENV: $APP_ENV"
if [ "$APP_ENV" = "production" ]; then
    echo "   ✅ APP_ENV is production"
else
    echo "   ⚠️  APP_ENV is not production, assets might use dev server"
fi

echo ""
echo "=========================================="
echo "✅ Vite Production Mode Fix Complete!"
echo "=========================================="
echo ""
echo "Now refresh your browser and check HTML source."
echo "Should see: /build/assets/app-[hash].css"
echo "NOT: http://localhost:5173"
echo ""