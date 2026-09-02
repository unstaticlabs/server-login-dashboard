# Show the dashboard only in interactive shells.
case $- in
  *i*) /usr/local/sbin/server-login-dashboard ;;
esac
