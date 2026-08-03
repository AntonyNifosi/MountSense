import urllib.request

# Mount rarity (% of players who own each mount) is no longer scraped here —
# it's provided at runtime by the embedded MountsRarity library (see
# Libs/MountsRarity/MountsRarity.lua), which is maintained upstream and kept
# in sync with DataForAzeroth automatically. Re-run tools/update_library.ps1
# (or just re-download that one file) to refresh it; this script only
# handles mount family classification, which has no equivalent library.
MJE_FAMILIES_URL = "https://raw.githubusercontent.com/exochron/MountJournalEnhanced/master/Database/families.db.lua"

def main():
    print("Téléchargement des familles de MountJournalEnhanced...")
    try:
        req = urllib.request.Request(MJE_FAMILIES_URL, headers={'User-Agent': 'Mozilla/5.0'})
        mje_data = urllib.request.urlopen(req).read().decode('utf-8')
    except Exception as e:
        print("Erreur de téléchargement MJE:", e)
        return

    out_lines = []
    out_lines.append("-- [AUTO-GENERATED FILE] Ne pas éditer manuellement.")
    out_lines.append("-- Voir l'historique git pour la date de dernière mise à jour.")
    out_lines.append("-- Source: " + MJE_FAMILIES_URL)
    out_lines.append("local _, addon = ...")
    out_lines.append("addon.ExternalData = addon.ExternalData or {}")
    out_lines.append("addon.ExternalData.MountFamilies = {}")
    out_lines.append("")

    current_family = None
    depth = 0
    mounts_family = {}
    
    for line in mje_data.split('\n'):
        line = line.strip()
        
        if line.startswith('["') and line.endswith(' = {') and depth == 0:
            current_family = line.split('"')[1]
            depth = 1
        elif line.startswith('["') and line.endswith(' = {') and depth == 1:
            depth = 2
        elif line.startswith('},') and depth == 2:
            depth = 1
        elif line.startswith('},') and depth == 1:
            depth = 0
            current_family = None
        elif line.startswith('[') and '] = ' in line and depth == 2:
            try:
                m_id = line.split('[')[1].split(']')[0]
                mounts_family[int(m_id)] = current_family
            except:
                pass

    out_lines.append("-- Familles (Extraites de MountJournalEnhanced)")
    for mid, fam in sorted(mounts_family.items()):
        out_lines.append(f"addon.ExternalData.MountFamilies[{mid}] = \"{fam}\"")

    out_lines.append("")

    with open('MountSenseDB_External.lua', 'w', encoding='utf-8') as f:
        f.write('\n'.join(out_lines))

    print(f"Succès! {len(mounts_family)} familles écrites dans MountSenseDB_External.lua")

if __name__ == '__main__':
    main()
