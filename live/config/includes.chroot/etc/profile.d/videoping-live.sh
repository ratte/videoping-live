# videoping live: start the X session with videoping on tty1.
# Not on other consoles (Ctrl+Alt+F2 ... F6 give a shell), not over ssh, and not when the
# kernel command line contains "videoping.noautostart".
if [ -z "${DISPLAY:-}" ] && [ "$(id -u)" -ge 1000 ] && [ "$(tty)" = /dev/tty1 ] \
   && ! grep -qw videoping.noautostart /proc/cmdline; then
  # When X ends, the login shell ends, getty logs in again and the session restarts.
  exec startx /usr/local/bin/videoping-session -- -nolisten tcp -keeptty > "$HOME/.xsession-errors" 2>&1
fi
