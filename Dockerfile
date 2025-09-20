# Imagen final que se ejecutará en Azure
FROM php:8.2-apache

# 1) Paquetes y extensiones PHP que usa OSPOS
RUN apt-get update \
 && apt-get install -y libicu-dev libgd-dev libzip-dev git unzip \
 && docker-php-ext-install mysqli bcmath intl gd zip pdo_mysql \
 && a2enmod rewrite

# 2) Instalar Composer (para generar /vendor en la imagen)
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
 && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
 && rm composer-setup.php

# 3) Variables PHP (timezone)
ENV PHP_TIMEZONE=UTC
RUN echo "date.timezone = \"${PHP_TIMEZONE}\"" > /usr/local/etc/php/conf.d/timezone.ini

# 4) Copiar código y generar vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction --no-progress
COPY . .

# 5) Apuntar Apache a /public y permitir .htaccess
RUN rm -rf /var/www/html \
 && ln -s /app /var/www/html \
 && sed -ri 's#DocumentRoot /var/www/html#DocumentRoot /var/www/html/public#' /etc/apache2/sites-available/000-default.conf \
 && sed -ri 's#<Directory /var/www/>#<Directory /var/www/html/public/>#' /etc/apache2/apache2.conf \
 && sed -ri 's#AllowOverride None#AllowOverride All#' /etc/apache2/apache2.conf

# 6) Permisos de carpetas que escribe la app
RUN chmod -R 770 /app/writable/uploads /app/writable/logs /app/writable/cache \
 && chown -R www-data:www-data /app

# 7) Puerto y comando de arranque
EXPOSE 80
CMD ["apache2-foreground"]
