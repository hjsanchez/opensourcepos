FROM php:8.2-apache

# 1) Paquetes del sistema, PHP ext, Apache rewrite, y Node.js (para npm/gulp)
RUN apt-get update \
 && apt-get install -y curl gnupg ca-certificates git unzip libicu-dev libgd-dev libzip-dev \
 && docker-php-ext-install mysqli bcmath intl gd zip pdo_mysql \
 && a2enmod rewrite \
 && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs

# 2) Zona horaria (puedes sobreescribir con App Setting PHP_TIMEZONE)
ENV PHP_TIMEZONE=America/Mexico_City
RUN echo "date.timezone = \"${PHP_TIMEZONE}\"" > /usr/local/etc/php/conf.d/timezone.ini

# 3) Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
 && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
 && rm composer-setup.php

WORKDIR /app

# 4) Instala dependencias PHP primero (mejor caché)
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction --no-progress

# 5) Instala dependencias JS y compila assets (gulp)
#    Copiamos package.json/lock y gulpfile antes para caché
COPY package*.json ./
# (si tienes gulpfile.js o gulpfile.cjs, descomenta la siguiente línea)
# COPY gulpfile.* ./
RUN npm ci

# 6) Copiamos TODO el código y ejecutamos el build front-end
COPY . .
RUN npm run build  # => ejecuta "gulp default" y genera /public/resources, /public/css, /public/js, etc.

# 7) Asegura que /public exista completo (redundante, pero claro)
#    (Si tu build deposita en otra carpeta, ajusta las rutas)
RUN test -d /app/public

# 8) Apache servirá /public y permitirá .htaccess
RUN rm -rf /var/www/html \
 && ln -s /app /var/www/html \
 && sed -ri 's#DocumentRoot /var/www/html#DocumentRoot /var/www/html/public#' /etc/apache2/sites-available/000-default.conf \
 && sed -ri 's#<Directory /var/www/>#<Directory /var/www/html/public/>#' /etc/apache2/apache2.conf \
 && sed -ri 's#AllowOverride None#AllowOverride All#' /etc/apache2/apache2.conf

# 9) Permisos de escritura
RUN chmod -R 770 /app/writable/uploads /app/writable/logs /app/writable/cache \
 && chown -R www-data:www-data /app

EXPOSE 80
CMD ["apache2-foreground"]
