sed 's/nextprot.org/alpha-nextprot.org/g' schema.ttl > alpha-schema.ttl
python3 pylode/pyLODE-2.13.2/pylode/cli.py -i ./alpha-schema.ttl  > alpha-schema.html
