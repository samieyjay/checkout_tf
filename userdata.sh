#!/bin/bash
/bin/touch /var/spool/cron/root
sudo /bin/echo '*/10 * * * * git pull origin/master /var/www/html/' >> /var/spool/cron/root
