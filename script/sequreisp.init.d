#!/bin/sh
#
# sequreisp     Startup script for the sequreISP ISP server solution.

NAME=sequreisp
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

command="/opt/sequreisp/scripts/boot.sh"
log=${command}.log
sequreispd_pid="/opt/sequreisp/deploy/shared/log/sequreispd.rb.pid"

start () {
        #if the daemon is not running (ie: just after reboot), there must be no pid file
        if [ -f $sequreispd_pid -a -z "$(pidof sequreispd.rb_monitor)" -a -z "$(pidof sequreispd.rb)" ];then
                rm $sequreispd_pid
        fi
        /opt/sequreisp/deploy/current/lib/daemons/sequreispd_ctl start
}

stop () {
        /opt/sequreisp/deploy/current/lib/daemons/sequreispd_ctl stop
}

case "$1" in
    start)
        echo -n "Starting $NAME: "
        $command 2>$log 1>$log
        start
        echo "$NAME."
        ;;
    stop)
        echo -n "Stopping $NAME: "
        initctl --quiet emit sequreisp-stopped
        stop
        ;;
    restart|reload)
        echo -n "Restarting $NAME: "
        stop
        start
        echo "$NAME."
        ;;
    *)
        echo "Usage: /etc/init.d/$NAME {start|stop|restart}"
        exit 3
        ;;
esac

exit 0