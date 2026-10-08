#!/bin/bash
# Finds the Apple development team(s) this Mac can sign with and writes the team ID into
# Configs/Signing.xcconfig. Run after signing into Xcode and creating a development
# certificate (README, "First-time setup", step 6).
# To pick a specific team: TEAM=XXXXXXXXXX make setup
set -euo pipefail
cd "$(dirname "$0")/../.."

CONFIG=Configs/Signing.xcconfig
[ -f "$CONFIG" ] || cp Configs/Signing.xcconfig.template "$CONFIG"

# One line per team: <team ID> <tab> personal|paid|unknown <tab> <team name>
TEAMS=$(python3 Tools/scripts/xcode_teams.py || true)

describe() {  # reads team lines, prints them for people
    while IFS=$'\t' read -r id kind name; do
        case "$kind" in
            personal) echo "  $name (Personal Team), team ID $id" ;;
            paid) echo "  $name, team ID $id" ;;
            *) echo "  $name, team ID $id (from a signing certificate)" ;;
        esac
    done
}

TEAM="${TEAM:-}"
if [ -z "$TEAM" ]; then
    COUNT=$(printf "%s" "$TEAMS" | grep -c . || true)
    # Prefer a paid team over the free Personal Team when Xcode says which is which.
    if [ "$COUNT" -gt 1 ]; then
        PAID=$(printf "%s\n" "$TEAMS" | grep $'\tpaid\t' || true)
        if [ "$(printf "%s" "$PAID" | grep -c .)" -eq 1 ]; then
            TEAMS="$PAID"
            COUNT=1
        fi
    fi
    if [ "$COUNT" -eq 0 ]; then
        echo "No Apple team found."
        echo "Xcode's settings list no team yet, and this Mac has no Apple Development certificate"
        echo "(which also names the team). In Xcode: Settings… (⌘,) → Accounts → select your"
        echo "Apple ID → select the team → Manage Certificates… → + → Apple Development → Done."
        echo "Then run this again. Details: README.md, \"First-time setup\", step 6."
        exit 1
    elif [ "$COUNT" -gt 1 ]; then
        echo "This Mac can sign with several teams:"
        printf "%s\n" "$TEAMS" | describe
        echo "Pick one: TEAM=<team ID> make setup"
        echo "The paid team's ID is on developer.apple.com/account under Membership details."
        exit 1
    fi
    KIND=$(printf "%s" "$TEAMS" | cut -f2)
    if [ "$KIND" != paid ] && [ -z "${ALLOW_PERSONAL_TEAM:-}" ]; then
        if [ "$KIND" = personal ]; then
            echo "Only the free Personal Team is available, so nothing was changed."
        else
            echo "Found one team, but its certificate doesn't say whether it's the free Personal Team"
            echo "or the paid team, so nothing was changed:"
            printf "%s\n" "$TEAMS" | describe
        fi
        echo "To use the Personal Team until the paid team is approved: ALLOW_PERSONAL_TEAM=1 make setup"
        echo "(then check that the team name it prints is yours). See CLAUDE.md, Signing."
        exit 1
    fi
    TEAM=$(printf "%s" "$TEAMS" | cut -f1)
fi

sed -i '' "s/^DEVELOPMENT_TEAM *=.*/DEVELOPMENT_TEAM = $TEAM/" "$CONFIG"
echo "Wrote DEVELOPMENT_TEAM = $TEAM to $CONFIG"
FOUND=$(printf "%s\n" "$TEAMS" | awk -F'\t' -v id="$TEAM" '$1 == id')
if [ -n "$FOUND" ]; then
    echo "Team:"
    printf "%s\n" "$FOUND" | describe
    echo "Check that the name is yours before the first signed build."
else
    echo "This Mac has no certificate or Xcode record for that team, so its name can't be shown."
fi
