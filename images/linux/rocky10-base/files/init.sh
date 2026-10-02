#!/bin/bash
# Login banners. The kickstart runs this file straight from the OEMDRV CD, chrooted into the
# installed system, in the %post section that also installs the RPMs from that CD.
set -euo pipefail

ESC=$'\e'
RESET="${ESC}[0m"
DIM="${ESC}[2m"
BOLD="${ESC}[1m"
# Rocky green, light to dark, as 256-colour codes (the Linux console shows the nearest of its
# 16 colours; SSH terminals show them as they are)
SHADES=(84 78 42 36 35 29)

ART=(
'██████╗  ██████╗  ██████╗██╗  ██╗██╗   ██╗     ██╗ ██████╗ '
'██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝╚██╗ ██╔╝    ███║██╔═████╗'
'██████╔╝██║   ██║██║     █████╔╝  ╚████╔╝     ╚██║██║██╔██║'
'██╔══██╗██║   ██║██║     ██╔═██╗   ╚██╔╝       ██║████╔╝██║'
'██║  ██║╚██████╔╝╚██████╗██║  ██╗   ██║        ██║╚██████╔╝'
'╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝   ╚═╝        ╚═╝ ╚═════╝ '
)

colour_art() {
    local i
    for i in "${!ART[@]}"; do
        printf '%s%s%s\n' "${ESC}[38;5;${SHADES[$i]}m" "${ART[$i]}" "$RESET"
    done
}

# Console, before login. agetty expands \n (hostname), \4 (IPv4), \r (kernel), \S{...} (os-release).
{
    echo
    colour_art
    echo
    printf '  %s\\S{PRETTY_NAME}%s  on  %s\\n%s\n' "$BOLD" "$RESET" "$BOLD" "$RESET"
    printf '  %sIPv4%s \\4   %skernel%s \\r\n' "$DIM" "$RESET" "$DIM" "$RESET"
    echo
} > /etc/issue

# SSH, before authentication. sshd prints this file verbatim, so plain text without escapes.
{
    echo
    printf '%s\n' "${ART[@]}"
    echo
    echo '  Authorised access only. Activity on this system is logged.'
    echo
} > /etc/issue.net

install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/50-banner.conf <<'EOF'
# Pre-authentication banner, written by init.sh
Banner /etc/issue.net
EOF

# After login: coloured art plus a live system summary for interactive login shells.
# /etc/motd stays empty so the summary is the only thing printed.
: > /etc/motd
{
    echo '# Login summary, written by init.sh'
    echo 'case $- in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac'
    echo '[ -n "${LOGIN_SUMMARY_SHOWN:-}" ] && return 0'
    echo 'export LOGIN_SUMMARY_SHOWN=1'
    echo 'printf "\n"'
    for i in "${!ART[@]}"; do
        printf 'printf "\\033[38;5;%sm%%s\\033[0m\\n" %q\n' "${SHADES[$i]}" "${ART[$i]}"
    done
    cat <<'EOF'
. /etc/os-release
_row() { printf '  \033[2m%-8s\033[0m %s\n' "$1" "$2"; }
printf '\n'
_row host   "$(hostname)"
_row os     "$PRETTY_NAME"
_row kernel "$(uname -r)"
_row ip     "$(hostname -I 2>/dev/null | awk '{print $1}')"
_row uptime "$(uptime -p | sed 's/^up //')"
_row load   "$(cut -d' ' -f1-3 /proc/loadavg)"
_row memory "$(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
_row disk   "$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
printf '\n'
unset -f _row
EOF
} > /etc/profile.d/zz-login-summary.sh
chmod 0644 /etc/profile.d/zz-login-summary.sh

echo "init.sh: banners installed"
