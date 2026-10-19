ARG PHP_VERSION=8.0-fpm-alpine
ARG IMAGICK_VERSION=3.7.0

# ==============================================================================
# Build extensions
# ==============================================================================
FROM php:${PHP_VERSION} AS builder

ARG IMAGICK_VERSION

RUN apk add --no-cache \
    $PHPIZE_DEPS \
    icu-dev \
    libzip-dev \
    imagemagick-dev \
    libpng-dev \
    libwebp-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    zlib-dev

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        gd \
        intl \
        zip \
        opcache

RUN mkdir -p /usr/src/php/ext \
    && curl -fsSL https://github.com/Imagick/imagick/archive/refs/tags/${IMAGICK_VERSION}.tar.gz -o imagick.tar.gz \
    && mkdir -p /usr/src/php/ext/imagick \
    && tar -xf imagick.tar.gz -C /usr/src/php/ext/imagick --strip-components=1 \
    && rm imagick.tar.gz \
    && docker-php-ext-install imagick

# ==============================================================================
# Create runtime image
# ==============================================================================
FROM php:${PHP_VERSION} AS runtime

RUN apk add --no-cache \
    git \
    unzip \
    imagemagick \
    libwebp \
    libgomp \
    icu \
    libzip \
    libpng \
    libjpeg-turbo \
    freetype

COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
    sed -i 's/short_open_tag = Off/short_open_tag = On/' "$PHP_INI_DIR/php.ini"
