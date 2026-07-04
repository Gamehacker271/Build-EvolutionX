#!/bin/bash

# Configuracao
TG_TOKEN="8143589998:AAHn1HSjS58k2TK5X2G4IG5bJnaJXpE68O8"
TG_CHAT_ID="-1003741233739"

# Funcao Telegram
send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT_ID}" \
        --data-urlencode text="$1" \
        -d parse_mode="Markdown" > /dev/null
}

# Funcao upload GoFile
upload_gofile() {
    local FILE="$1"
    
    if [ ! -f "$FILE" ]; then
        echo "ERRO: Arquivo nao encontrado: $FILE"
        return 1
    fi
    
    SERVER=$(curl -ks https://api.gofile.io/servers | jq -r '.data.servers[0].name')
    
    if [[ -z "$SERVER" || "$SERVER" == "null" ]]; then
        echo "ERRO: Nao foi possivel obter servidor GoFile"
        return 1
    fi
    
    EXPIRE_DATE=$(date -d "+3 days" +%s)
    
    LINK=$(curl -k# -F "file=@$FILE" \
        -F "expiry=$EXPIRE_DATE" \
        "https://${SERVER}.gofile.io/uploadFile" | jq -r '.data.downloadPage')
    
    if [[ -z "$LINK" || "$LINK" == "null" ]]; then
        echo "ERRO: Upload falhou"
        return 1
    fi
    
    echo "$LINK"
}

# Main
main() {
    if [[ "$#" == '0' ]]; then
        echo "ERRO: Nenhum arquivo especificado"
        echo "Uso: $0 /caminho/para/arquivo.zip"
        exit 1
    fi
    
    FILE="$1"
    FILE_NAME=$(basename "$FILE")
    FILE_SIZE=$(du -h "$FILE" | cut -f1)
    EXPIRE_DATE=$(date -d "+3 days" "+%d/%m/%Y %H:%M")
    
    DOWNLOAD_LINK=$(upload_gofile "$FILE")
    
    if [ $? -eq 0 ] && [ -n "$DOWNLOAD_LINK" ]; then
        echo "Nome: $FILE_NAME"
        echo "Tamanho: $FILE_SIZE"
        echo "Download: $DOWNLOAD_LINK"
        echo "Expira em: $EXPIRE_DATE"
        
        send_telegram "*Nome*: $FILE_NAME
*Tamanho*: $FILE_SIZE
*Download*: $DOWNLOAD_LINK
*Expira em*: $EXPIRE_DATE"
    else
        echo "Falha no upload"
        exit 1
    fi
}

main "$@"
