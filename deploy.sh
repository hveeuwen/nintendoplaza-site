#!/bin/sh
# Haalt nieuwe versies van nintendoplaza.nl op bij GitHub en zet ze op de site.
# Draait elke 5 minuten via een eigen cronjob in DirectAdmin.
#
# Waarom: sinds 16 november 2026 kan GitHub deze server niet meer bereiken.
# Daarom haalt de server het nu zelf op. Zie scripts/publiceer.py in nintendoplaza.nl.
#
# Naast de cronjob voor wittesneakers.com. Daarom eigen namen voor de tijdelijke
# map (.nintendoplaza-tmp), het versiebestand (.nintendoplaza-versie) en het
# logboek (nintendoplaza-deploy.log), zodat de twee elkaar nooit raken.
#
# De cronjob haalt dit script op via een VASTE commit (niet via 'main'), zodat
# wat er op de server draait niet stilletjes kan veranderen.
#
# Verwijdert nooit iets, laat de .htaccess in de webroot met rust en neemt
# geen PHP-bestanden over.

exec >> "$HOME/nintendoplaza-deploy.log" 2>&1
cd "$HOME" || exit 1

REPO=hveeuwen/nintendoplaza-site
WEBMAP="$HOME/domains/nintendoplaza.nl/public_html"
TMP=.nintendoplaza-tmp
VERSIE=.nintendoplaza-versie

if [ ! -d "$WEBMAP" ]; then
    echo "$(date) WEBMAP BESTAAT NIET: $WEBMAP"
    exit 1
fi

# curl, met wget als terugval voor het geval curl ontbreekt.
haal() { curl -fsSL --max-time 300 "$1" 2>/dev/null || wget -qO- --timeout=300 "$1"; }

# Snelle check: is er een nieuwe versie? Zo niet, dan meteen stoppen.
nieuw=$(haal "https://raw.githubusercontent.com/$REPO/main/versie.txt") || exit 0
[ -n "$nieuw" ] || exit 0
[ "$nieuw" = "$(cat "$VERSIE" 2>/dev/null)" ] && exit 0

rm -rf "$TMP" && mkdir "$TMP" || exit 1
PAKKET="https://codeload.github.com/$REPO/tar.gz/refs/heads/main"
if haal "$PAKKET" | tar xz -C "$TMP" --strip-components=1; then
    rm -f "$TMP/README.md" "$TMP/.htaccess" "$TMP/deploy.sh"
    find "$TMP" -iname '*.php' -delete
    if cp -R "$TMP"/. "$WEBMAP"/; then
        # De versie uit het gedownloade pakket zelf, zodat versie en inhoud
        # altijd bij elkaar horen.
        cat "$TMP/versie.txt" > "$VERSIE"
        echo "$(date) gepubliceerd: $(cat "$VERSIE")"
    else
        echo "$(date) KOPIEREN MISLUKT"
    fi
else
    echo "$(date) OPHALEN MISLUKT"
fi
rm -rf "$TMP"
