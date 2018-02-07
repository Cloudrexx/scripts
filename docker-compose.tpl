# This file is used as a template for ./cx init
# The "image" option always needs to be right after the service name. Otherwise
# ./cx will not be able to re-extract values from the parsed file.
version: '2'
services:
  web:
    image: "<php-image>"
    hostname: "<hostname>"<novhost>
    ports:
      - "<port>:80"</novhost>
    volumes:
      - <cd>:/var/www/html<vhost>
    environment:
      - VIRTUAL_HOST=<hostname></vhost>
    depends_on:
      - db
      - usercache
    networks:
      - front-end
      - back-end
  db:
    image: "<db-image>"
    command: --sql-mode="NO_ENGINE_SUBSTITUTION" --character-set-server=utf8 --collation-server=utf8_general_ci
    volumes:
      - db-data:/var/lib/mysql
    networks:
      - back-end
    environment:
      - MYSQL_ROOT_PASSWORD=123456
      - MYSQL_DATABASE=dev
  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    hostname: "phpma.<hostname>"
    environment:
      - PMA_ARBITRARY=1
      - PMA_HOST=db
      - PMA_USER=root
      - PMA_PASSWORD=123456<vhost>
      - VIRTUAL_HOST=phpma.<hostname></vhost>
    networks:
      - front-end
      - back-end
    depends_on:
      - db
    restart: always<novhost>
    ports:
      - 8234:80</novhost>
  usercache:
    image: "memcached"
    networks:
      - back-end
networks:
  front-end:<vhost>
    external:
      name: <proxy-network></vhost>
  back-end:
volumes:
  db-data:
