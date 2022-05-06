import csv, json
import sys, requests
import logging #log file
from pathlib import Path
import re

logging.basicConfig(format='%(asctime)s\t%(levelname)s\t%(message)s', level=logging.INFO)

logging.info("### Start file generation for PDB-eKB...")

input_file = sys.argv[1]
output_folder_path = sys.argv[2]

def get3LetterCode(aa):
	if aa == "":
		return ""

	switcher = {
	"G": "Gly",
	"P": "Pro",
	"A": "Ala",
	"V": "Val",
	"L": "Leu",
	"I": "Ile",
	"M": "Met",
	"C": "Cys",
	"F": "Phe",
	"Y": "Tyr",
	"W": "Trp",
	"H": "His",
	"K": "Lys",
	"R": "Arg",
	"Q": "Gln",
	"N": "Asn",
	"E": "Glu",
	"D": "Asp",
	"S": "Ser",
	"T": "Thr"
    }
	output = ""
	for element in aa:
		output = output + switcher.get(element, "Invalid 1-letter code:" + element)
		
	return output

release_info_resp = requests.get("https://api.nextprot.org/release-info.json")
release_info_json = release_info_resp.json()
resource_version = release_info_json['versions']['databaseRelease']
version_split = resource_version.split('-');
release_date = version_split[2] + "/" + version_split[1] + "/" + version_split[0]

pdb_entries = dict()
with open(input_file, "r") as csv_file:
	reader = csv.DictReader(csv_file, delimiter=',', quotechar='"')
	for num, row in enumerate(reader):
		#if (len(row['varAA']) > 1):
		#	logging.warning("Variant amino acid is longer than 1 in row " + str(num) + ": " + str(row))
		#	continue
		if (len(row['orgAA']) != 1):
			logging.warning("Original amino acid is not equals to 1 in row " + str(num) + ": " + str(row))
			continue
		entry = row['entryAcc'].split('/')[5]
		pdb_split = row['pdb'].split(";") # ex: 6K9L; chain=A/B
		pdbid = pdb_split[0].strip()
		chain_list =  pdb_split[1].strip().split("=")[1].split("/")
		pdb_res_label = row['varPos']
		aa_type = get3LetterCode(row['orgAA'])
		aa_variant = get3LetterCode(row['varAA'])
		phvarDesc = row['phvarDescription']  # ex: (IDH1-p.Tyr139Asp) decreases isocitrate dehydrogenase (NADP+) activity
		start_label = phvarDesc.index('-p.') + 1
		end_label = phvarDesc.index(')')
		label = phvarDesc[start_label:end_label]
		description = phvarDesc[end_label+2: len(phvarDesc)]

		if "Invalid" in aa_type: 
			 logging.error("Unexpected amino acid: " + row['orgAA'])
		if "Invalid" in aa_variant: 
			 logging.error("Unexpected amino acid: " + row['varAA'])

		if pdbid in pdb_entries:
			site_id_ref = len(pdb_entries[pdbid]['sites']) + 1
		else:
			site_id_ref = 1
		
		site = {
			"site_id": site_id_ref,
			"label": label,
			"site_url": "https://www.nextprot.org/entry/" + entry + "/phenotype",
			"source_database": "neXtProt",
			"source_accession": entry
		}
		site_data = {
			"site_id_ref": site_id_ref,
			"confidence_classification": "curated",
			"confidence_score": 1,
			"aa_variant_causes": description
		}
		if (len(aa_variant) > 0):
			# if it's not a deletion, we add the 'aa_variant'
			site_data["aa_variant"] = aa_variant
			
		residue = {
			"pdb_res_label": pdb_res_label,
			"aa_type": aa_type,
			"site_data": [ site_data ]
		}

		ecoAccs = row['ecoAccs'].split(';')
		ecoLabels = row['ecoLabels'].split(';')
		ecos = []
		for ecoNum, ecoAcc in enumerate(ecoAccs):
			ecos.append({
				"eco_term": ecoLabels[ecoNum],
				"eco_code": ecoAcc.split('/')[5]
			})
		if pdbid in pdb_entries:
			logging.debug("entry to update: " + str(pdbid))
			pdb_entries[pdbid]['sites'].append(site)
			existing_chains = pdb_entries[pdbid]['chains']
			
			chain0 = existing_chains[0]
			existing_residues = chain0['residues'];
			found_res_label = False; 
			for existing_residue in existing_residues:
				if pdb_res_label == existing_residue['pdb_res_label']:
					found_res_label = True
					# if we update a residue, we don't need to do it in all chains because it's the same object
					existing_residue['site_data'].append(site_data)
			if found_res_label == False:
				for existing_chain in existing_chains:
					existing_chain['residues'].append(residue)
			found_eco = False; 
			for eco in ecos:
				for existing_eco in pdb_entries[pdbid]['evidence_code_ontology']:
					if eco['eco_code'] == existing_eco['eco_code']:
						found_eco = True
						break
				if found_eco == False:
					pdb_entries[pdbid]['evidence_code_ontology'].append(eco)
		else:
			logging.debug("entry to create: " + str(pdbid))
			chains = []
			for chain_name in chain_list:
				chains.append({"chain_label": chain_name, "residues": [ residue ]})

			pdb_entries[pdbid] = {
				"data_resource": "nextprot",
				"resource_version": resource_version,
				"resource_entry_url": "https://nextprot.org",
				"release_date": release_date,
				"pdb_id": pdbid,
				"chains": chains,
				"sites": [ site ],
				"evidence_code_ontology": ecos
			}

logging.debug(pdb_entries)

for entry in pdb_entries:
	folder = entry[1:3]
	Path(output_folder_path + "/" + folder).mkdir(parents=True, exist_ok=True)
	entry_file = open(output_folder_path + "/" + folder + "/" + entry + ".json", "w")
	entry_file.write(json.dumps(pdb_entries[entry], indent=4, sort_keys=True))
	entry_file.close()

logging.info("### End of file generation for PDB-eKB.")
