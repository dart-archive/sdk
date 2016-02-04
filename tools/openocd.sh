#! /bin/bash
third_party/openocd/linux/openocd/bin/openocd -f board/stm32f7discovery.cfg --search third_party/openocd/linux/openocd/share/openocd/scripts >/tmp/stconnect.log 2>&1 &
PID=$!

timeout 5s tail -f /tmp/stconnect.log

telnet 127.0.0.1 4444
kill $PID
