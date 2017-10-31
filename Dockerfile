FROM php:7.1-apache

ENV LIB_DIR /var/lib/pflegebedarf
ENV WWW_DIR /var/www/html/pflegebedarf

COPY schema $LIB_DIR/schema
COPY api $WWW_DIR/api
COPY ui/html $WWW_DIR/ui

RUN chown -R www-data:www-data $LIB_DIR $WWW_DIR
