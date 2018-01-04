FROM cloudrexx/web:PHP7.0
RUN bash -c "apt update && apt install -y \
    # Ubuntu packages
        cron \
    # Configuration
        && echo '* * * * * /var/www/html/cx Cron' | crontab -"
