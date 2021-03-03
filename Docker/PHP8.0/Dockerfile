FROM php:8.0
RUN bash -c "apt update"
RUN bash -c "apt install -y \
    # Ubuntu packages
        exiftool \
        libmemcached-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libsodium-dev \
        libpng-dev \
        libicu-dev \
        zlib1g-dev \
        libzip-dev \
        msmtp \
        ssl-cert"
    # PHP extensions
RUN bash -c "curl -L https://github.com/FriendsOfPHP/pickle/releases/download/v0.6.0/pickle.phar > pickle.phar && chmod +x pickle.phar && mv pickle.phar /usr/local/bin/pickle \
        && docker-php-ext-configure exif && docker-php-ext-install exif && docker-php-ext-enable exif \
        && docker-php-ext-configure gd && docker-php-ext-install -j$(nproc) gd \
        && docker-php-ext-install -j$(nproc) iconv opcache mysqli pdo_mysql intl bcmath zip sodium \
        && pickle install memcached && echo extension=memcached.so >> /usr/local/etc/php/conf.d/memcached.ini \
    # PHP configuration
        && echo 'date.timezone = \"UTC\"' >> /usr/local/etc/php/php.ini \
        && echo 'default_socket_timeout = 600' >> /usr/local/etc/php/php.ini \
        && echo 'sendmail_path = /usr/sbin/msmtp -t --read-envelope-from' >> /usr/local/etc/php/php.ini \
    # Apache configuration
        && a2enmod rewrite \
        && a2enmod expires \
        && a2enmod headers \
        && a2enmod ssl \
        && echo \"UseCanonicalName On\" >> /etc/apache2/apache2.conf \
        && ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf \
    # Cleanup
        && apt-get autoremove -y \
        && apt-get remove -y \
            libfreetype6-dev \
            libpng-dev \
            libmemcached-dev \
            libsodium-dev \
            libjpeg62-turbo-dev \
            libicu-dev \
            zlib1g-dev \
            libzip-dev \
        && apt-get clean \
        && rm -rf /tmp/pear"
COPY clx-docker-msmtp-config /etc/msmtprc
COPY clx-docker-php-entrypoint /usr/local/bin/
EXPOSE 443
ENTRYPOINT ["clx-docker-php-entrypoint"]
CMD ["apache2-foreground"]
