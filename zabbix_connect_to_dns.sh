#!/usr/bin/env bash
# Simple script which switch "Connect To" in host config to DNS and optionally removes IP completely.
# Get Zabbix DBName DBUser and DBPassword
conf_file="/etc/zabbix/zabbix_server.conf"
eval "$(grep '^DBName=' $conf_file)"
eval "$(grep '^DBUser=' $conf_file)"
eval "$(grep '^DBPassword=' $conf_file)"
# Regex for domain validatin taken from here https://stackoverflow.com/a/41193739/2444141
# Unit test for it https://regex101.com/r/d5Yd6j/1/tests
domain_re="^(?=.{1,253}\.?$)(?:(?!-|[^.]+_)[A-Za-z0-9-_]{1,63}(?<!-)(?:\.|$)){2,}$"
mysqlcmd="mysql -u$DBUser -p$DBPassword -D$DBName --batch --skip-column-names -e"
domain_name=""
action=""
removeip=0

_help(){
echo "Usage:
  -h                    This help
  -a domain.tld         Run for all hosts which ends with 'domain.tld'
  -n host.domain.tld    Run for host 'host.domain.tld'
  -r                    Also remove IP from host
Note: parameters -a and -n are mutually exclusive."
}

_validatedomain(){
    echo "$1" | grep -qP "$domain_re"
    if [[ $? -eq 0 ]]; then
        return 0;
    else
        echo "Domain validation failed." >&2
        return 1;
    fi
}

_switchall(){
    if [[ $domain_name ]]; then
        $mysqlcmd "SELECT CASE WHEN ip = '' THEN '-' ELSE ip END, dns FROM interface WHERE dns LIKE '%$domain_name';" 2> /dev/null | \
        while read -r ip dns; do
            $mysqlcmd "UPDATE interface SET useip = 0 WHERE dns = '$dns';" 2> /dev/null
            echo "Host '$dns' switched to DNS."
            if [[ $removeip -eq 1 ]]; then
                $mysqlcmd "UPDATE interface SET ip = '' WHERE dns = '$dns';" 2> /dev/null
                echo "IP '${ip/-}' removed from host '$dns'."
            fi
        done
    else
        echo "No domain name provided!" >&2
        exit 1
    fi
    exit 0
}

_switchone(){
    if [[ $domain_name ]]; then
        $mysqlcmd "UPDATE interface SET useip = 0 WHERE dns = '$domain_name';" 2> /dev/null
        echo "Host '$domain_name' switched to DNS."
        if [[ $removeip -eq 1 ]]; then
            ip=$($mysqlcmd "SELECT ip FROM interface WHERE dns LIKE '%$domain_name';" 2> /dev/null)
            $mysqlcmd "UPDATE interface SET ip = '' WHERE dns = '$domain_name';" 2> /dev/null
            echo "IP '$ip' removed from host '$domain_name'."
        fi
    else
        echo "No domain name provided!" >&2
        exit 1
    fi
    exit 0
}

# Show help if no parameters provided.
if [[ $# -eq 0 ]]; then
    _help
fi

while [ ${#} -gt 0 ]; do
    case "$1" in
        -h | --help)
            # Show help
            _help
            exit 0
            ;;
        -a)
            # Run for all domains like $2
            if [[ $action ]]; then
                echo "You can't use -a and -n simultaneously!"
                exit 1
            else
                action="all"
            fi
            if _validatedomain "$2"; then
                domain_name="$2"
            else
                echo "No domain specified or invalid domain name!" >&2
                exit 1
            fi
            shift 2
            ;;
        -n)
            # Run for single domain
            if [[ $action ]]; then
                echo "You can't use -n and -a simultaneously!"
                exit 1
            else
                action="one"
            fi
            if _validatedomain "$2"; then
                domain_name="$2"
            else
                echo "No domain specified or invalid domain name!" >&2
                exit 1
            fi
            shift 2
           ;;
        -r)
            # Remove IP from domain
            removeip=1
            shift
            ;;
        -c)
            _validatedomain "$2" && echo "Valid domain."
            exit 0;
            ;;
        --) # End of all options
            shift
            break
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
        *)
            # No more options, break from loop
            break
            ;;
    esac
done

case "$action" in
    one)
        _switchone
        ;;
    all)
        _switchall
        ;;
esac
