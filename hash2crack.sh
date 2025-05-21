#!/bin/bash
# Script para ayudar a identificar hashes y probar John the Ripper/Hashcat


# Colores para mejor visualización :D
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Configuración inicial
JOHN_FORMATS=$(john --list=formats 2>/dev/null | tr ' ' '\n' | grep -v "^$")
HCAT_MODES=$(hashcat --help 2>/dev/null | grep -E "^ *[0-9]{1,5} \|" | tr -s " " | sed 's/ | /|/g')

# Mapa ampliado de correspondencias entre formatos comunes
# Formato: [Nombre identificable] = "john_format:hashcat_mode"
declare -A FORMAT_MAP=(
    ["MD5"]="raw-md5:0"
    ["SHA-1"]="raw-sha1:100"
    ["SHA-256"]="raw-sha256:1400"
    ["SHA-512"]="raw-sha512:1700"
    ["SHA-512CRYPT"]="sha512crypt:1800"
    ["SHA-384"]="raw-sha384:10800"
    ["SHA3-256"]="raw-sha3-256:17400"
    ["SHA3-512"]="raw-sha3-512:17600"
    ["RIPEMD-160"]="ripemd-160:6000"
    ["WHIRLPOOL"]="whirlpool:6100"
    ["GOST"]="gost:6900"
    ["MD4"]="raw-md4:900"
    ["NTLM"]="nt:1000"
    ["LM"]="lm:3000"
    ["MYSQL"]="mysql:200"
    ["MYSQL5"]="mysql-sha1:300"
    ["ORACLE"]="oracle:3100"
    ["MSSQL"]="mssql:131"
    ["MSSQL2005"]="mssql05:132"
    ["MSSQL2012"]="mssql12:1731"
    ["POSTGRESQL"]="postgres:12"
    ["BCRYPT"]="bcrypt:3200"
    ["SCRYPT"]="scrypt:8900"
    ["ARGON2"]="argon2:16900"
    ["PHPASS"]="phpass:400"
    ["WORDPRESS"]="phpass:400"
    ["DRUPAL7"]="drupal7:7900"
    ["DRUPAL8"]="drupal8:17700"
    ["JOOMLA"]="joomla:11"
    ["PHPBB3"]="phpbb3:400"
    ["DCC"]="mscash:1100"
    ["DCC2"]="mscash2:2100"
    ["WPA"]="wpapsk:2500"
    ["SIP"]="sip:11400"
    ["NETNTLMV1"]="netntlmv1:5500"
    ["NETNTLMV2"]="netntlmv2:5600"
    ["KERBEROS"]="krb5pa:7500"
    ["KERBEROS-TGS"]="krb5tgs:13100"
    ["RACF"]="racf:8500"
    ["LOTUS"]="lotus5:8600"
    ["MSCASH"]="mscash:1100"
    ["MSCASH2"]="mscash2:2100"
    ["CRAM-MD5"]="cram-md5:10200"
    ["HMAC-MD5"]="hmac-md5:50"
    ["HMAC-SHA1"]="hmac-sha1:150"
    ["HMAC-SHA256"]="hmac-sha256:1450"
    ["OPENSSL-PBKDF2"]="pbkdf2-hmac-sha1:10900"
    ["1PASSWORD"]="agilekeychain:6600"
    ["LASTPASS"]="lastpass:6800"
    ["KEEPASS"]="keepass:13400"
    ["7-ZIP"]="7z:11600"
    ["RAR5"]="rar5:13000"
    ["PDF"]="pdf:10500"
    ["ZIP2"]="zip2:13600"
)

# Función para identificar un hash
identificar_hash() {
    local HASH="$1"
    HASH=$(echo "$HASH" | tr -d '[:space:]') # Eliminar espacios

    echo -e "\n${AMARILLO}========================================${RESET}"
    echo -e "${CYAN}Analizando hash: ${VERDE}$HASH${RESET}"
    echo -e "${AMARILLO}========================================${RESET}"

    # Usar hashid para identificar posibles tipos de hash
    CANDIDATOS=$(hashid "$HASH" 2>/dev/null | grep -E "\[\+\] [A-Za-z0-9-]+" | awk '{$1=""; print $0}' | sed 's/^ *//' | head -n8)
    
    # En caso que falle el hash id intentaremos por nuestros medios
    if [ -z "$CANDIDATOS" ]; then
        echo -e "${AMARILLO}[!] No se pudo identificar automáticamente el hash.${RESET}"
        # Determinación basada en longitud (método de respaldo)
        determinar_por_longitud "$HASH"
        return 1
    fi

    echo -e "\n${VERDE}Posibles formatos identificados:${RESET}"
    
    # Procesar cada candidato
    IFS=$'\n'
    for FORMATO in $CANDIDATOS; do
        FORMATO=$(echo "$FORMATO" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        buscar_correspondencia "$FORMATO" "$HASH"
    done
}

# Función para determinar formato por longitud como respaldo en caso de fallo de hashid
determinar_por_longitud() {
    local HASH="$1"
    local LEN=${#HASH}
    
    echo -e "\n${AMARILLO}Intentando determinar formato por longitud (${LEN} caracteres):${RESET}"
    
    case $LEN in
        32)
            echo -e "  ${VERDE}Posible${RESET}: MD5 / MD4"
            echo -e "  ${CYAN}Hashcat${RESET}: -m 0 (MD5) o -m 900 (MD4)"
            echo -e "  ${CYAN}John${RESET}: --format=raw-md5 o --format=raw-md4"
            ;;
        40)
            echo -e "  ${VERDE}Posible${RESET}: SHA-1 / RIPEMD-160"
            echo -e "  ${CYAN}Hashcat${RESET}: -m 100 (SHA-1) o -m 6000 (RIPEMD-160)"
            echo -e "  ${CYAN}John${RESET}: --format=raw-sha1 o --format=ripemd-160"
            ;;
        64)
            echo -e "  ${VERDE}Posible${RESET}: SHA-256 / BLAKE2b-256"
            echo -e "  ${CYAN}Hashcat${RESET}: -m 1400 (SHA-256)"
            echo -e "  ${CYAN}John${RESET}: --format=raw-sha256"
            ;;
        96)
            echo -e "  ${VERDE}Posible${RESET}: SHA-384"
            echo -e "  ${CYAN}Hashcat${RESET}: -m 10800"
            echo -e "  ${CYAN}John${RESET}: --format=raw-sha384"
            ;;
        128)
            echo -e "  ${VERDE}Posible${RESET}: SHA-512 / BLAKE2b-512"
            echo -e "  ${CYAN}Hashcat${RESET}: -m 1700 (SHA-512)"
            echo -e "  ${CYAN}John${RESET}: --format=raw-sha512"
            ;;
        *)
            echo -e "  ${AMARILLO}No se puede determinar formato solo por longitud.${RESET}"
            echo -e "  ${AMARILLO}Longitud del hash${RESET}: $LEN caracteres"
            ;;
    esac
}

# Buscar correspondencia específica para un formato 
buscar_correspondencia() {
    local FORMATO="$1"
    local HASH="$2"
    
    # Buscar términos clave para mejores coincidencias
    for CLAVE in "${!FORMAT_MAP[@]}"; do
        if echo "$FORMATO" | grep -i -q "$CLAVE"; then
            IFS=':' read -r JOHN_FORMAT HCAT_MODE <<< "${FORMAT_MAP[$CLAVE]}"
            echo -e "\n${VERDE}[+] Formato detectado${RESET}: $FORMATO (Coincide con $CLAVE)"
            echo -e "  ${CYAN}Hashcat${RESET}: -m $HCAT_MODE"
            echo -e "  ${CYAN}John${RESET}: --format=$JOHN_FORMAT"
            echo -e "  ${AMARILLO}Comando John${RESET}: john --format=$JOHN_FORMAT hash.txt --worldlist=wordlist.txt"
            echo -e "  ${AMARILLO}Comando Hashcat${RESET}: hashcat -m $HCAT_MODE -a 0 hash.txt wordlist.txt"
            return 0
        fi
    done
    
    # Si no encontramos correspondencia directa, buscar en las listas completas
    JOHN_FORMAT=$(echo "$JOHN_FORMATS" | grep -i -m1 -w "$FORMATO" || echo "?")
    HCAT_MODE=$(echo "$HCAT_MODES" | grep -i -m1 "$FORMATO" | cut -d'|' -f1 | tr -d ' ' || echo "?")
    
    if [ "$JOHN_FORMAT" != "?" ] || [ "$HCAT_MODE" != "?" ]; then
        echo -e "\n${VERDE}[+] Posible formato${RESET}: $FORMATO"
        [ "$HCAT_MODE" != "?" ] && echo -e "  ${CYAN}Hashcat${RESET}: -m $HCAT_MODE"
        [ "$JOHN_FORMAT" != "?" ] && echo -e "  ${CYAN}John${RESET}: --format=$JOHN_FORMAT"
    fi
}


# Función para limpiar directorio de hashes
limpiar_directorio_hashes() {
    # Crea el directorio si no existe, o limpia su contenido si existe
    if [ -d "./hashes" ]; then
        echo -e "${AMARILLO}Limpiando directorio de hashes...${RESET}"
        rm -f ./hashes/*
    else
        mkdir -p ./hashes 2>/dev/null
    fi

    # Limpiar potfiles de John the Ripper
    #echo -e "${AMARILLO}Limpiando potfiles de John the Ripper...${RESET}"
    rm -f ~/.john/john.pot 2>/dev/null
    rm -f ./john.pot 2>/dev/null

    # Limpiar potfiles de Hashcat
    #echo -e "${AMARILLO}Limpiando potfiles de Hashcat...${RESET}"
    rm -f ~/.hashcat/hashcat.potfile 2>/dev/null
    rm -f ./hashcat.potfile 2>/dev/null
    #rm -f ~/.hashcat/hashcat.potfile

    # Alternativa: usar los comandos de las herramientas para limpiar potfiles
    john --pot=john.pot --show=john.pot &>/dev/null
    hashcat --potfile-path=hashcat.potfile --potfile-disable &>/dev/null
}

# Función para generar hashes
hashear_texto() {
    local TEXTO="$1"
    local SALT="$2"
    
    limpiar_directorio_hashes
    
    echo -e "\n${AMARILLO}========================================${RESET}"
    echo -e "${VERDE}Generando hashes para texto: \"$TEXTO\"${RESET}"
    [ -n "$SALT" ] && echo -e "${VERDE}Usando salt: \"$SALT\"${RESET}"
    echo -e "${AMARILLO}========================================${RESET}"
    
    mkdir -p ./hashes 2>/dev/null
    
    # Sin salt
    if [ -z "$SALT" ]; then
        echo -n "$TEXTO" | md5sum | awk '{print $1}' > ./hashes/hash_md5.txt
        echo -n "$TEXTO" | sha1sum | awk '{print $1}' > ./hashes/hash_sha1.txt
        echo -n "$TEXTO" | sha256sum | awk '{print $1}' > ./hashes/hash_sha256.txt
        echo -n "$TEXTO" | sha512sum | awk '{print $1}' > ./hashes/hash_sha512.txt
        
        echo -e "\n${CYAN}=== Hashes generados (guardados en ./hashes/) ===${RESET}"
        echo -e "${VERDE}MD5${RESET}:      $(cat ./hashes/hash_md5.txt)"
        echo -e "${VERDE}SHA-1${RESET}:    $(cat ./hashes/hash_sha1.txt)"
        echo -e "${VERDE}SHA-256${RESET}:  $(cat ./hashes/hash_sha256.txt)"
        echo -e "${VERDE}SHA-512${RESET}:  $(cat ./hashes/hash_sha512.txt)"
    else
        # Con salt
        # Usando OpenSSL para hashes con salt
        openssl passwd -1 -salt "$SALT" "$TEXTO" > ./hashes/hash_md5crypt.txt
        if command -v mkpasswd &> /dev/null; then
            mkpasswd -m sha-512 "$TEXTO" > ./hashes/hash_sha512crypt.txt
        else
            echo "$TEXTO" | openssl passwd -6 -salt "$SALT" > ./hashes/hash_sha512crypt.txt
        fi
        
        # Crear hash bcrypt si está disponible
        if command -v htpasswd &> /dev/null; then
            htpasswd -bnBC 10 "" "$TEXTO$SALT" | tail -c +2 > ./hashes/hash_bcrypt.txt
        fi
        
        echo -e "\n${CYAN}=== Hashes salteados generados (guardados en ./hashes/) ===${RESET}"
        echo -e "${VERDE}MD5-Crypt${RESET}:    $(cat ./hashes/hash_md5crypt.txt)"
        
        if [ -f "./hashes/hash_sha512crypt.txt" ]; then
            echo -e "${VERDE}SHA512-Crypt${RESET}: $(cat ./hashes/hash_sha512crypt.txt)"
        fi
        
        if [ -f "./hashes/hash_bcrypt.txt" ]; then
            echo -e "${VERDE}Bcrypt${RESET}:      $(cat ./hashes/hash_bcrypt.txt)"
        fi
    fi
    
    echo -e "\n${CYAN}=== Comandos para crackear ===${RESET}"
    if [ -z "$SALT" ]; then
        # Hashcat commands
        echo -e "${AMARILLO}Hashcat:${RESET}"
        echo -e "${VERDE}MD5${RESET}:      hashcat -m 0 ./hashes/hash_md5.txt wordlist.txt --potfile-disable"
        echo -e "${VERDE}SHA-1${RESET}:    hashcat -m 100 ./hashes/hash_sha1.txt wordlist.txt --potfile-disable"
        echo -e "${VERDE}SHA-256${RESET}:  hashcat -m 1400 ./hashes/hash_sha256.txt wordlist.txt --potfile-disable"
        echo -e "${VERDE}SHA-512${RESET}:  hashcat -m 17600 ./hashes/hash_sha512.txt wordlist.txt --potfile-disable"
        
        # John commands
        echo -e "\n${AMARILLO}John the Ripper:${RESET}"
        echo -e "${VERDE}MD5${RESET}:      john --format=raw-md5 ./hashes/hash_md5.txt --wordlist=wordlist.txt"
        echo -e "${VERDE}SHA-1${RESET}:    john --format=raw-sha1 ./hashes/hash_sha1.txt --wordlist=wordlist.txt"
        echo -e "${VERDE}SHA-256${RESET}:  john --format=raw-sha256 ./hashes/hash_sha256.txt --wordlist=wordlist.txt"
        echo -e "${VERDE}SHA-512${RESET}:  john --format=raw-sha512 ./hashes/hash_sha512.txt --wordlist=wordlist.txt"
    else
        # Hashcat commands for salted hashes
        echo -e "${AMARILLO}Hashcat:${RESET}"
        echo -e "${VERDE}MD5-Crypt${RESET}:    hashcat -m 500 ./hashes/hash_md5crypt.txt wordlist.txt --potfile-disable"
        [ -f "./hashes/hash_sha512crypt.txt" ] && echo -e "${VERDE}SHA512-Crypt${RESET}: hashcat -m 1800 ./hashes/hash_sha512crypt.txt wordlist.txt --potfile-disable"
        [ -f "./hashes/hash_bcrypt.txt" ] && echo -e "${VERDE}Bcrypt${RESET}:      hashcat -m 3200 ./hashes/hash_bcrypt.txt wordlist.txt --potfile-disable"
        
        # John commands for salted hashes
        echo -e "\n${AMARILLO}John the Ripper:${RESET}"
        echo -e "${VERDE}MD5-Crypt${RESET}:    john --format=md5crypt ./hashes/hash_md5crypt.txt --wordlist=wordlist.txt"
        [ -f "./hashes/hash_sha512crypt.txt" ] && echo -e "${VERDE}SHA512-Crypt${RESET}: john --format=sha512crypt ./hashes/hash_sha512crypt.txt --wordlist=wordlist.txt"
        [ -f "./hashes/hash_bcrypt.txt" ] && echo -e "${VERDE}Bcrypt${RESET}:      john --format=bcrypt ./hashes/hash_bcrypt.txt --wordlist=wordlist.txt"
    fi
}

# Función de ayuda
mostrar_ayuda() {
    echo -e "${VERDE}Hash Helper - Script para identificación y generación de hashes${RESET}"
    echo
    echo -e "${CYAN}Uso:${RESET}"
    echo "  $0 <hash>                          # Identificar un hash específico"
    echo "  $0 -f, --file <archivo.txt>        # Identificar hashes en un archivo"
    echo "  $0 -t, --text \"texto plano\"        # Generar hashes comunes a partir de texto"
    echo "  $0 -t \"texto\" -s, --salt \"salt\"    # Generar hashes salteados"
    echo "  $0 -h, --help                      # Mostrar esta ayuda"
    echo
    echo -e "${CYAN}Ejemplos:${RESET}"
    echo "  $0 5f4dcc3b5aa765d61d8327deb882cf99"
    echo "  $0 -f hashes.txt"
    echo "  $0 -t \"password123\""
    echo "  $0 -t \"password123\" -s \"mysalt\""
    echo
}

# Procesar argumentos
HASH=""
ARCHIVO=""
TEXTO=""
SALT=""

# Si no hay argumentos, mostrar ayuda
if [ $# -eq 0 ]; then
    mostrar_ayuda
    exit 0
fi

# Limpiar el directorio de hashes al inicio
limpiar_directorio_hashes

# Procesar argumentos con soporte para formatos largos
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        -f|--file)
            shift
            ARCHIVO="$1"
            if [ ! -f "$ARCHIVO" ]; then
                echo -e "${AMARILLO}Error: El archivo $ARCHIVO no existe.${RESET}"
                exit 1
            fi
            ;;
        -t|--text)
            shift
            TEXTO="$1"
            ;;
        -s|--salt)
            shift
            SALT="$1"
            ;;
        *)
            # Si no es una opción, asumimos que es un hash
            if [ -z "$HASH" ] && [ -z "$ARCHIVO" ] && [ -z "$TEXTO" ]; then
                HASH="$1"
            fi
            ;;
    esac
    shift
done

# Ejecutar la función correspondiente según los argumentos
if [ -n "$ARCHIVO" ]; then
    echo -e "${VERDE}Procesando hashes desde el archivo: $ARCHIVO${RESET}"
    while read -r LINE; do
        [ -z "$LINE" ] && continue  # Saltar líneas vacías
        identificar_hash "$LINE"
    done < "$ARCHIVO"
elif [ -n "$TEXTO" ]; then
    hashear_texto "$TEXTO" "$SALT"
elif [ -n "$HASH" ]; then
    identificar_hash "$HASH"
else
    echo -e "${AMARILLO}Error: No se proporcionaron argumentos válidos.${RESET}"
    mostrar_a

fi
