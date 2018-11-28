#!/bin/sh

## @param file
file_exists() {
    if [ -f "$1" ]; then
        return 0
    fi
    return 1
}

## @param match
## @param line
## @param file
lineinfile() {
    [ "$#" -lt 3 ] && return 1

    match="$1"
    line="$2"
    shift
    shift

    for file in "$@"; do
        file_exists "$file" || return 1
        grep -q "${match}" "$file" && sed "s|${match}.*|${line}|" -i "$file" || echo "$line" >> "$file"
    done

    return 0
}

## @param match
## @param file
linefromfile() {
    [ "$#" -lt 2 ] && return 1

    match=$1
    shift

    for file in "$@"; do
        file_exists "$file" || return 1
        sed -i "/${match}/d" "$file"
    done
}

## @param daemon name
reload_systemd_daemon() {
  local daemon="$1"
    if systemctl is-active --quiet "${daemon}"; then
        systemctl daemon-reload
        systemctl restart "${daemon}"
    fi
}

## @param daemon name
configure_container_runtime_proxy() {
  local daemon="$1"
  local systemd_runtime_dir="/etc/systemd/system/${daemon}.service.d"
  local systemd_proxy_config_file="${systemd_runtime_dir}/http-proxy.conf"
  mkdir -p "${systemd_runtime_dir}"

  if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$NO_PROXY" ] || [ -n "$http_proxy" ] ||  [ -n "$FTP_PROXY" ]; then
      echo "[Service]" > "${systemd_proxy_config_file}"
      [ -n "$HTTP_PROXY" ] && echo "Environment=\"HTTP_PROXY=${HTTP_PROXY}\"" >> "${systemd_proxy_config_file}"
      [ -n "$HTTPS_PROXY" ] && echo "Environment=\"HTTPS_PROXY=${HTTPS_PROXY}\"" >> "${systemd_proxy_config_file}"
      [ -n "$NO_PROXY" ] && echo "Environment=\"NO_PROXY=${NO_PROXY}\"" >> "${systemd_proxy_config_file}"
      [ -n "$http_proxy" ] && echo "Environment=\"http_proxy=${http_proxy}\"" >> "${systemd_proxy_config_file}"
      [ -n "$FTP_PROXY" ] && echo "Environment=\"FTP_PROXY=${FTP_PROXY}\"" >> "${systemd_proxy_config_file}"
      reload_systemd_daemon "${daemon}"
  else
      if [ -f "${SYSTEMD_PROXY_CFG_FILE}" ]; then
          rm -f "${SYSTEMD_PROXY_CFG_FILE}"
          reload_systemd_daemon "${daemon}"
      fi
  fi
}
