FROM php:8.0.0-fpm-alpine3.12 as base

RUN apk --update add --no-cache \
    ${PHPIZE_DEPS} \
    libpng-dev \
    openssl-dev \
    gd \
    "libxml2-dev>=2.9.10-r5" \
    git \
    "freetype>=2.10.4-r0" \
    && rm -rf /var/cache/apk/*

# Installing onigure manually to bypass vulnerability CVE-2020-26159 because the fix isn't available yet in alpine 
RUN apk update && \
    apk del oniguruma && \
    wget -c https://github.com/kkos/oniguruma/releases/download/v6.9.6_rc4/onig-6.9.6-rc4.tar.gz -O - | tar -xz && \
    (cd onig-6.9.6 && ./configure && make install) && \
    rm -rf ./onig-6.9.6 && \
    rm -rf /var/cache/apk/*

RUN docker-php-ext-install \
        mbstring \
        gd \
        soap \
        xml \
        posix \
        tokenizer \
        ctype \
        pcntl \
        opcache \
        && pecl install -f apcu \
        && echo 'extension=apcu.so' > /usr/local/etc/php/conf.d/30_apcu.ini \
        && chmod -R 755 /usr/local/lib/php/extensions/ \
        && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \
        && mkdir -p /app \
        && chown -R www-data:www-data /app

WORKDIR /app

FROM base as dev

ARG APP_STAGE
ENV APP_STAGE $APP_STAGE

ENV XDEBUG_VERSION 3.0.2
ENV COMPOSER_VERSION 2.0.13

# install system dependencies
RUN apk --update add --no-cache \
        autoconf \
        bash \
        build-base \
        git \
        pcre-dev \
        python3 \
        supervisor \
        nginx

# install database extension
RUN docker-php-ext-install pdo_mysql

COPY --chown=www-data:www-data ./docker/php/config/ /
COPY --chown=www-data:www-data ./src .

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer --version=$COMPOSER_VERSION

# Dev dependencies
RUN if [ "$APP_STAGE" == "dev" ] ; then \
        pecl install xdebug-$XDEBUG_VERSION ;\
    else \
        mv /extensions/opcache.ini /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini \
        && composer install --no-dev --no-interaction --optimize-autoloader ; \
    fi

RUN chmod +x /docker-entrypoint.sh

RUN chown -R www-data: .

ENTRYPOINT [ "/docker-entrypoint.sh" ]