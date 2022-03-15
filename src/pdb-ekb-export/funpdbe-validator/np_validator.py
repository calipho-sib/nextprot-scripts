import sys
from validator.validator import Validator
from validator.residue_index import ResidueIndexes

print("# Start validation of " + sys.argv[1])
validator = Validator("nextprot") # Same as in the JSON
validator.load_schema()
validator.load_json(sys.argv[1])
if validator.basic_checks() and validator.validate_against_schema():
    # Passed data validations
    print('INFO:  Passed schema validation')
    residue_indexes = ResidueIndexes(validator.json_data)
    if residue_indexes.check_every_residue():
        # Passed the index validation
        print('INFO:  Passed index validation')
    else: 
        print('ERROR: Failed index validation: ' + str(residue_indexes.mismatches))

else:
    print('ERROR: Failed schema validation: ' + str(validator.error_log))
print("# End validation of " + sys.argv[1])
print("")
