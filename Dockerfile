FROM php:7.1-apache

ENV LIB_DIR /usr/lib/pflegebedarf
ENV CGI_DIR /usr/lib/cgi-bin/pflegebedarf
ENV WWW_DIR /var/www/html

RUN ln -s /etc/apache2/mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load

RUN mkdir -p $LIB_DIR && echo 'betreff=Bestellung vom {datum}\nvon=Foobar <foo@bar>\nantwort=Barfoo <bar@foo>\nkopien=Foobar <foo@bar>,Barfoo <bar@foo>' > $LIB_DIR/versenden.ini

COPY api/target/debug/api $CGI_DIR/
COPY ui/html $WWW_DIR/ui

RUN chown -R www-data:www-data $LIB_DIR $WWW_DIR
