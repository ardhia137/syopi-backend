FROM php:8.3-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    nginx \
    nodejs \
    npm \
    nano \
    vim

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Get Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy existing application directory
COPY . /var/www

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/sites-available/default

# Copy environment file dari .env.docker
COPY .env.docker .env

# Install dependencies (without --no-dev untuk include dev packages seperti Pail)
RUN composer install --no-interaction --optimize-autoloader --ignore-platform-reqs || \
    composer install --no-interaction --optimize-autoloader --no-dev --ignore-platform-reqs

# Install npm dependencies and build assets for PRODUCTION
RUN npm install

# Build Vite assets
RUN npm run build

# IMPORTANT: Remove hot file to prevent Vite dev server detection
RUN rm -f /var/www/public/hot

# Debug: Check if build files exist
RUN echo "=== Checking Vite build output ===" && \
    ls -la /var/www/public/build/ || echo "Build directory not found" && \
    ls -la /var/www/public/build/.vite/ || echo ".vite directory not found" && \
    cat /var/www/public/build/manifest.json || echo "manifest.json not found"

# Generate APP_KEY after build
RUN php artisan key:generate --force

# Clear all caches after build
RUN php artisan optimize:clear

# Cache configuration for production (AFTER clearing and AFTER build)
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

# Link storage untuk public assets
RUN php artisan storage:link || true

# Set permissions untuk public/build
RUN chmod -R 755 /var/www/public

# Set permissions
RUN chown -R www-data:www-data /var/www \
    && chmod -R 775 /var/www/storage \
    && chmod -R 775 /var/www/bootstrap/cache

# Create startup script
RUN echo '#!/bin/bash\n\
# Fix permissions setiap start\n\
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache\n\
chmod -R 775 /var/www/storage /var/www/bootstrap/cache\n\
# Remove hot file if exists (prevent Vite dev server detection)\n\
rm -f /var/www/public/hot\n\
# DO NOT cache config here - use pre-built cache from Dockerfile\n\
php-fpm -D\n\
nginx -g "daemon off;"' > /start.sh && chmod +x /start.sh

EXPOSE 3323

CMD ["/start.sh"]