import urllib.request
import re
import datetime
import json

MJE_FAMILIES_URL = "https://raw.githubusercontent.com/exochron/MountJournalEnhanced/master/Database/families.db.lua"
DFA_INDEX_URL = "https://dataforazeroth.com/dynamic/index.json"

def main():
    print("Téléchargement des familles de MountJournalEnhanced...")
    try:
        req = urllib.request.Request(MJE_FAMILIES_URL, headers={'User-Agent': 'Mozilla/5.0'})
        mje_data = urllib.request.urlopen(req).read().decode('utf-8')
    except Exception as e:
        print("Erreur de téléchargement MJE:", e)
        return

    print("Téléchargement de l'index DataForAzeroth...")
    try:
        req = urllib.request.Request(DFA_INDEX_URL, headers={'User-Agent': 'MountsRarity'})
        dfa_index_raw = urllib.request.urlopen(req).read().decode('utf-8')
        dfa_index = json.loads(dfa_index_raw)
        rarity_path = dfa_index.get('mountsrarity')
        if not rarity_path:
            raise Exception("Pas de champ mountsrarity dans le JSON")
    except Exception as e:
        print("Erreur de téléchargement Index DFA:", e)
        return

    print(f"Téléchargement des raretés depuis {rarity_path} ...")
    try:
        url = "https://www.dataforazeroth.com" + rarity_path
        req = urllib.request.Request(url, headers={'User-Agent': 'MountsRarity'})
        rarity_data = urllib.request.urlopen(req).read().decode('utf-8')
    except Exception as e:
        print("Erreur de téléchargement Raretés DFA:", e)
        return

    out_lines = []
    out_lines.append("-- [AUTO-GENERATED FILE] Ne pas éditer manuellement.")
    out_lines.append("-- Généré le: " + datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    out_lines.append("local _, addon = ...")
    out_lines.append("addon.Data = addon.Data or {}")
    out_lines.append("addon.ExternalData = {}")
    out_lines.append("addon.ExternalData.MountFamilies = {}")
    out_lines.append("addon.ExternalData.MountRarities = {}")
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

    mounts_rarity = {}
    # The JSON from DataForAzeroth is like: {"6":56.4533, ...}
    try:
        rarity_json = json.loads(rarity_data)
        for k, v in rarity_json.get('mounts', {}).items():
            mounts_rarity[int(k)] = float(v)
    except Exception as e:
        print("Erreur parsing JSON rareté:", e)
        return

    out_lines.append("-- Raretés (Extraites de DataForAzeroth)")
    for mid, rar in sorted(mounts_rarity.items()):
        out_lines.append(f"addon.ExternalData.MountRarities[{mid}] = {rar}")

    out_lines.append("")
    
    with open('MountSenseDB_External.lua', 'w', encoding='utf-8') as f:
        f.write('\n'.join(out_lines))
        
    print(f"Succès! {len(mounts_family)} familles et {len(mounts_rarity)} pourcentages écrits dans MountSenseDB_External.lua")

if __name__ == '__main__':
    main()
