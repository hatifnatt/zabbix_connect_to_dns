#!/usr/bin/env bash
# Simple script which switch "Connect To" in host config to DNS and optionally removes IP completely.
# Get Zabbix DBName DBUser and DBPassword
conf_file="/etc/zabbix/zabbix_server.conf"
eval "$(grep '^DBName=' $conf_file)"
eval "$(grep '^DBUser=' $conf_file)"
eval "$(grep '^DBPassword=' $conf_file)"
eval "$(grep '^DBHost=' $conf_file)"
# Regex for domain validatin taken from here https://stackoverflow.com/a/41193739/2444141
# Unit test for it https://regex101.com/r/d5Yd6j/1/tests
domain_re="^(?=.{1,253}\.?$)(?:(?!-|[^.]+_)[A-Za-z0-9-_]{1,63}(?<!-)(?:\.|$)){2,}$"
dbtype="mysql"
domain_name=""
action=""
removeip=0

_help(){
echo "Usage:
  -h                    This help
  -a domain.tld         Run for all hosts which ends with 'domain.tld'
  -n host.domain.tld    Run for host 'host.domain.tld'
  -r                    Also remove IP from host
  -t dbtype             dbtype can be postgres or mysql, mysql is default
Note: parameters -a and -n are mutually exclusive."
}

_sqlcmd(){
    case $dbtype in
        mysql)
            mysql -h${DBHost:-localhost} -u$DBUser -p$DBPassword -D$DBName --batch --skip-column-names -e "$1"
            ;;
        postgres)
            psql -F' ' -q --no-align --tuples-only -c "$1"
            ;;
        *)
            echo "Error: Unknown DB type: $2" >&2
            return 1
            ;;
    esac
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

_testconnection(){
    case $dbtype in
        mysql)
            if ! which mysql >/dev/null 2>&1; then
                echo "Error: mysql executable not found" >&2
                exit 1
            fi
            ;;
        postgres)
            if ! which psql >/dev/null 2>&1; then
                echo "Error: psql executable not found" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown DB type: $2" >&2
            exit 1
            ;;
    esac
    if err="$(_sqlcmd "\q")"; then
        echo "Connection to $dbtype server '$DBHost' sucessfull"
    else
        echo "Connection to $dbtype server on '$DBHost' failed" >&2
        echo "$err" >&2
        exit 1
    fi
}

_switchall(){
    if [[ $domain_name ]]; then
        _sqlcmd "SELECT CASE WHEN ip = '' THEN '-' ELSE ip END, dns FROM interface WHERE dns LIKE '%$domain_name';" 2> /dev/null | \
        while read -r ip dns; do
            _sqlcmd "UPDATE interface SET useip = 0 WHERE dns = '$dns';" && \
            echo "Host '$dns' switched to DNS."
            if [[ $removeip -eq 1 ]]; then
                _sqlcmd "UPDATE interface SET ip = '' WHERE dns = '$dns';" && \
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
        _sqlcmd "UPDATE interface SET useip = 0 WHERE dns = '$domain_name';" && \
        echo "Host '$domain_name' switched to DNS."
        if [[ $removeip -eq 1 ]]; then
            ip=$(_sqlcmd "SELECT ip FROM interface WHERE dns LIKE '%$domain_name';")
            _sqlcmd "UPDATE interface SET ip = '' WHERE dns = '$domain_name';" && \
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
        -t)
            case "$2" in
                mysql)
                    dbtype="mysql"
                    ;;
                postgres)
                    dbtype="postgres"
                    export PGUSER=$DBUser
                    export PGPASSWORD=$DBPassword
                    export PGDATABASE=$DBName
                    export PGHOST=${DBHost:-localhost}
                    ;;
                *)
                    echo "Error: Unknown DB type: $2" >&2
                    exit 1
                    ;;
            esac
            shift 2
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
        _testconnection
        _switchone
        ;;
    all)
        _testconnection
        _switchall
        ;;
esac
