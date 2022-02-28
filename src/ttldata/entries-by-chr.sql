select gi.chromosome, count(distinct si.unique_name) as entries
from nextprot.sequence_identifiers si
inner join nextprot.mapping_annotations map on (si.identifier_id=map.mapped_identifier_id)
inner join nextprot.sequence_identifiers g on (g.identifier_id=map.reference_identifier_id)
inner join nextprot.gene_identifiers gi on (g.identifier_id=gi.identifier_id)
where si.cv_type_id=1 and si.cv_status_id=1
and g.cv_type_id=3 and g.cv_status_id=1
and map.cv_quality_qualifier_id != 100
group by gi.chromosome
order by gi.chromosome
;
