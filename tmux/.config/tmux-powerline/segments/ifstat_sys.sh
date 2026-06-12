# shellcheck shell=bash

run_segment() {
  local sleeptime="0.5"
  local iface

  if tp_shell_is_macos; then
    iface=$(route get default | grep -i interface | awk '{print $2}')
    [ -z "$iface" ] && iface="en0"
    local RXB TXB RXBN TXBN
    RXB=$(netstat -i -b | grep -m 1 "$iface" | awk '{print $7}')
    TXB=$(netstat -i -b | grep -m 1 "$iface" | awk '{print $10}')
    sleep "$sleeptime"
    RXBN=$(netstat -i -b | grep -m 1 "$iface" | awk '{print $7}')
    TXBN=$(netstat -i -b | grep -m 1 "$iface" | awk '{print $10}')
  else
    iface=$(ip route | grep "default" | grep -o "dev.*" | cut -d ' ' -f 2)
    if [ -z "$iface" ]; then
      iface=$(awk '{if($2>0 && NR > 2) print substr($1, 0, index($1, ":") - 1)}' /proc/net/dev | sed '/^lo$/d')
    fi
    local RXB TXB RXBN TXBN
    RXB=$(</sys/class/net/"$iface"/statistics/rx_bytes)
    TXB=$(</sys/class/net/"$iface"/statistics/tx_bytes)
    sleep "$sleeptime"
    RXBN=$(</sys/class/net/"$iface"/statistics/rx_bytes)
    TXBN=$(</sys/class/net/"$iface"/statistics/tx_bytes)
  fi

  _fmt_rate() {
    local bytes=$1 sleeptime=$2
    awk -v b="$bytes" -v s="$sleeptime" 'BEGIN {
			rate = b / s
			if (rate < 1024)        { printf "%.0fB/s", rate }
			else if (rate < 1048576){ printf "%.1fK/s", rate / 1024 }
			else                    { printf "%.1fM/s", rate / 1048576 }
		}'
  }

  local rx_bytes tx_bytes
  rx_bytes=$((RXBN - RXB))
  tx_bytes=$((TXBN - TXB))

  printf "󰇚 %s 󰕒 %s" "$(_fmt_rate "$rx_bytes" "$sleeptime")" "$(_fmt_rate "$tx_bytes" "$sleeptime")"
  return 0
}
