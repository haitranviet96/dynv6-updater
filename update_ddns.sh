#!/bin/bash

# Dynv6 API settings
source .env

# Function to exit the script on error
exit_on_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
    exit 1
}

# Fetch current public IPv4 and IPv6 addresses
echo -e "\n\n[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] -------------- STARTING UPDATE DYNV6 DDNS ---------------" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Fetching current public IPs..." >&2
CURRENT_IPV4=$(curl -s http://ipv4.icanhazip.com) || exit_on_error "Failed to fetch IPv4 address."
CURRENT_IPV6=$(curl -s http://icanhazip.com) || exit_on_error "Failed to fetch IPv6 address."
# Check if the current DNS matches the desired IPs
DNS_IPV4=$(dig +short $DOMAIN A)
DNS_IPV6=$(dig +short $DOMAIN AAAA)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Current IPv4: $CURRENT_IPV4" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Current IPv6: $CURRENT_IPV6" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Current DNS IPv4: $DNS_IPV4" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Current DNS IPv6: $DNS_IPV6" >&2

# Function to retrieve the zoneID for a specific domain
get_zone_id() {
    local zone_id
    zone_id=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "https://dynv6.com/api/v2/zones" | jq -r ".[] | select(.name==\"$DOMAIN\") | .id")
    [[ -z "$zone_id" ]] && exit_on_error "Could not retrieve zoneID for $DOMAIN."
    echo "$zone_id"
}

# Function to retrieve all records for a specific zoneID
get_zone_records() {
    local zone_id=$1
    local records
    records=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "https://dynv6.com/api/v2/zones/$zone_id/records")
    [[ -z "$records" ]] && exit_on_error "Could not retrieve records for zoneID: $zone_id."
    echo "$records"
}

# Function to update zone ip addresses
update_zone() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Updating zone IP Addresses $DOMAIN ..." >&2
    token="$TOKEN" ./dynv6.sh "$DOMAIN" || exit_on_error "Failed to update record: $name"
}

# Function to update an existing record
update_record() {
    local zone_id=$1
    local record_id=$2
    local name=$3
    local type=$4
    local value=$5

    # Build payload
    local payload
    payload="{\"name\":\"$name\",\"type\":\"$type\",\"value\":\"$value\"}"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Updating record with ID: $record_id, Payload: $payload" >&2
    curl -s -X PATCH "https://dynv6.com/api/v2/zones/$zone_id/records/$record_id" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" || exit_on_error "Failed to update record: $name"
}

# Function to create a new record
create_record() {
    local zone_id=$1
    local name=$2
    local type=$3
    local data=$4

    # Build payload
    local payload
    payload="{\"name\":\"$name\",\"type\":\"$type\",\"data\":\"$data\"}"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Creating new record: $name, Payload: $payload" >&2
    curl -s -X POST "https://dynv6.com/api/v2/zones/$zone_id/records" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" || exit_on_error "Failed to create record: $name"
}

# Main domain updates
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Checking main domain AAAA/A record ($DOMAIN)..." >&2
if [[ -n "$DNS_IPV4" && -n "$DNS_IPV6" ]]; then
    if [[ "$CURRENT_IPV4" != "$DNS_IPV4" || "$CURRENT_IPV6" != "$DNS_IPV6" ]]; then
        update_zone
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $DOMAIN A/AAAA record is already up-to-date." >&2
    fi
else
    update_zone
fi

# Retrieve the zoneID for the domain
ZONE_ID=$(get_zone_id)
echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Retrieved zoneID: $ZONE_ID" >&2

# Fetch all records for the zone
ZONE_RECORDS=$(get_zone_records $ZONE_ID)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Retrieved zone records:" >&2
echo "$ZONE_RECORDS" | jq . >&2

# Wildcard subdomain update
# AAAA
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Checking wildcard domain AAAA record (*.$DOMAIN)..." >&2
WILDCARD_AAAA_RECORD=$(echo "$ZONE_RECORDS" | jq -r ".[] | select(.name==\"*\" and .type==\"AAAA\")")
if [[ -n "$WILDCARD_AAAA_RECORD" ]]; then
    WILDCARD_RECORD_ID=$(echo "$WILDCARD_AAAA_RECORD" | jq -r ".id")
    WILDCARD_DNS_IPV6=$(echo "$WILDCARD_AAAA_RECORD" | jq -r ".data")

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Wildcard AAAA record (*) is already up-to-date." >&2

    if [[ "$CURRENT_IPV6" != "$WILDCARD_DNS_IPV6" ]]; then
        update_record $ZONE_ID $WILDCARD_RECORD_ID "*" "AAAA" "$CURRENT_IPV6"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] Wildcard AAAA record (*) is already up-to-date." >&2
    fi
else
    create_record $ZONE_ID "*" "AAAA" "$CURRENT_IPV6"
fi

# Wildcard subdomain update
# A
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Checking wildcard domain A record (*.$DOMAIN)..." >&2
WILDCARD_A_RECORD=$(echo "$ZONE_RECORDS" | jq -r ".[] | select(.name==\"*\" and .type==\"A\")")
if [[ -n "$WILDCARD_A_RECORD" ]]; then
    WILDCARD_RECORD_ID=$(echo "$WILDCARD_A_RECORD" | jq -r ".id")
    WILDCARD_DNS_IPV4=$(echo "$WILDCARD_A_RECORD" | jq -r ".data")

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Wildcard A record (*) is already up-to-date." >&2

    if [[ "$CURRENT_IPV4" != "$WILDCARD_DNS_IPV4" ]]; then
        update_record $ZONE_ID $WILDCARD_RECORD_ID "*" "A" "$CURRENT_IPV4"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] Wildcard A record (*) is already up-to-date." >&2
    fi
else
    create_record $ZONE_ID "*" "A" "$CURRENT_IPV4"
fi


echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] DDNS update complete." >&2
