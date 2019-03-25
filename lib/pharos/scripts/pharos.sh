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

    unset match
    unset line

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
    unset match
}

## @param daemon name
reload_systemd_daemon() {
  daemon="$1"
    if systemctl is-active --quiet "${daemon}"; then
        systemctl daemon-reload
        systemctl restart "${daemon}"
    fi
    unset daemon
}

## @param daemon name
configure_container_runtime_proxy() {
  daemon="$1"
  systemd_runtime_dir="/etc/systemd/system/${daemon}.service.d"
  systemd_proxy_config_file="${systemd_runtime_dir}/http-proxy.conf"
  mkdir -p "${systemd_runtime_dir}"
  # shellcheck disable=SC2154
  if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$NO_PROXY" ] || [ -n "$http_proxy" ] || [ -n "$https_proxy" ] || [ -n "$no_proxy" ] || [ -n "$FTP_PROXY" ]; then
      echo "[Service]" > "${systemd_proxy_config_file}"
      [ -n "$HTTP_PROXY" ] && echo "Environment=\"HTTP_PROXY=${HTTP_PROXY}\"" >> "${systemd_proxy_config_file}"
      [ -n "$HTTPS_PROXY" ] && echo "Environment=\"HTTPS_PROXY=${HTTPS_PROXY}\"" >> "${systemd_proxy_config_file}"
      [ -n "$NO_PROXY" ] && echo "Environment=\"NO_PROXY=${NO_PROXY}\"" >> "${systemd_proxy_config_file}"
      [ -n "$http_proxy" ] && echo "Environment=\"http_proxy=${http_proxy}\"" >> "${systemd_proxy_config_file}"
      [ -n "$https_proxy" ] && echo "Environment=\"https_proxy=${https_proxy}\"" >> "${systemd_proxy_config_file}"
      [ -n "$no_proxy" ] && echo "Environment=\"no_proxy=${no_proxy}\"" >> "${systemd_proxy_config_file}"
      [ -n "$FTP_PROXY" ] && echo "Environment=\"FTP_PROXY=${FTP_PROXY}\"" >> "${systemd_proxy_config_file}"
      reload_systemd_daemon "${daemon}"
  else
      if [ -f "${systemd_proxy_config_file}" ]; then
          rm -f "${systemd_proxy_config_file}"
          reload_systemd_daemon "${daemon}"
      fi
  fi
  unset daemon
  unset systemd_proxy_config_file
  unset systemd_runtime_dir
}
