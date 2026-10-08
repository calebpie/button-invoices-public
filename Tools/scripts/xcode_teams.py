"""Prints each Apple development team this Mac knows as
"<team ID><tab><kind><tab><team name>", where kind is personal (the free Personal Team),
paid, or unknown. Arguments, if any, are keychain files to search instead of the
default keychains (for testing).

Two sources, merged:
1. Xcode's preferences, which flag the free Personal Team. Xcode has stored teams under
   different keys across versions, so this searches the whole plist for dictionaries
   with a teamID. Xcode 27.0 writes them late: on the M4 Max (Oct 2026), right after
   sign-in the preferences held only the Apple ID, and IDEProvisioningTeamByIdentifier
   appeared once an Apple Development certificate had been created.
2. Apple Development signing certificates in the keychain. Each names its team ID
   (subject OU) and team name (subject O) but not whether the team is free, so these
   teams are reported as unknown. Xcode creates one in Settings → Accounts → Manage
   Certificates (README, "First-time setup", step 6)."""

import plistlib
import re
import subprocess
import sys


def output(args, stdin=None):
    return subprocess.run(args, input=stdin, capture_output=True).stdout


def preference_teams():
    teams = {}

    def walk(node):
        if isinstance(node, dict):
            if "teamID" in node:
                name = node.get("teamName", "?")
                free = node.get("isFreeProvisioningTeam") or "Personal Team" in name
                name = name.replace(" (Personal Team)", "")
                teams[node["teamID"]] = ("personal" if free else "paid", name)
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    try:
        walk(plistlib.loads(output(["defaults", "export", "com.apple.dt.Xcode", "-"])))
    except plistlib.InvalidFileException:
        pass
    return teams


def certificate_teams(keychains):
    # Certificates with their private key on this Mac, expired or not: any of them
    # names the team, and Xcode makes a fresh certificate when it signs if needed.
    identities = output(["security", "find-identity", "-p", "codesigning", *keychains]).decode()
    hashes = set(re.findall(r'\b([0-9A-F]{40}) "Apple Development: ', identities))
    certificates = output(["security", "find-certificate", "-a", "-Z", "-p",
                           "-c", "Apple Development: ", *keychains]).decode()
    teams = {}
    for block in certificates.split("SHA-1 hash: ")[1:]:
        sha1, _, pem = block.partition("\n")
        if sha1.strip() not in hashes:
            continue
        subject = output(["openssl", "x509", "-noout", "-subject",
                          "-nameopt", "multiline,utf8,-esc_msb"], pem.encode()).decode()
        fields = dict(re.findall(r"^\s*(\w+)\s*= (.*)$", subject, re.M))
        team_id = fields.get("organizationalUnitName", "")
        if re.fullmatch(r"[A-Z0-9]{10}", team_id):
            teams[team_id] = ("unknown", fields.get("organizationName", "?"))
    return teams


teams = certificate_teams(sys.argv[1:])
teams.update(preference_teams())  # Xcode's record says which team is free
for team_id, (kind, name) in teams.items():
    print(f"{team_id}\t{kind}\t{name}")
