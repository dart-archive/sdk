#! /bin/bash
third_party/bin/openocd/linux/openocd/bin/openocd -f interface/stlink-v2-1.cfg -f board/stm32756g_eval.cfg --search third_party/bin/openocd/linux/openocd/share/openocd/scripts >/tmp/stconnect.log 2>&1 &
PID=$!

timeout 5s tail -f /tmp/stconnect.log

telnet 127.0.0.1 4444
kill $PID
