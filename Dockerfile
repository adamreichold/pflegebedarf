FROM php:7.1-apache

ENV LIB_DIR /usr/lib/pflegebedarf
ENV WWW_DIR /var/www/html/pflegebedarf

RUN mkdir -p $LIB_DIR && echo 'betreff=Bestellung vom {datum}\nvon=Foobar <foo@bar>\nantwort=Barfoo <bar@foo>\nkopien[]=Foobar <foo@bar>\nkopien[]=Barfoo <bar@foo>' > $LIB_DIR/versenden.ini

COPY lib $LIB_DIR
COPY api $WWW_DIR/api
COPY ui/html $WWW_DIR/ui

RUN chown -R www-data:www-data $LIB_DIR $WWW_DIR
