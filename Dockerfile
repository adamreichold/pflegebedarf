FROM php:7.1-apache

ENV LIB_DIR /usr/lib/pflegebedarf
ENV WWW_DIR /var/www/html/pflegebedarf

COPY lib $LIB_DIR
COPY api $WWW_DIR/api
COPY ui/html $WWW_DIR/ui

RUN chown -R www-data:www-data $LIB_DIR $WWW_DIR
