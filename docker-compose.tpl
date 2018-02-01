# This file is used as a template for ./cx init
# The "image" option always needs to be right after the service name. Otherwise
# ./cx will not be able to re-extract values from the parsed file.
version: '2'
services:
  web:
    image: "<php-image>"<novhost>
    ports:
      - "<port>:80"</novhost>
    volumes:
      - .:/var/www/html
    environment:
      - APACHE_RUN_USER=$UID
      - APACHE_RUN_GROUP=$GROUPS<vhost>
      - VIRTUAL_HOST=<hostname></vhost>
  db:
    image: "<db-image>"
    command: --sql-mode="NO_ENGINE_SUBSTITUTION"
    volumes:
      - ./tmp/data/db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=123456
      - MYSQL_DATABASE=dev
  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    environment:
      - PMA_ARBITRARY=1
      - PMA_HOST=db
      - PMA_USER=root
      - PMA_PASSWORD=123456<vhost>
      - VIRTUAL_HOST=phpma.<hostname></vhost>
    depends_on:
      - db
    restart: always<novhost>
    ports:
      - 8234:80</novhost>
  usercache:
    image: "memcached"<vhost>
networks:
  default:
    external:
      name: <proxy-network></vhost>