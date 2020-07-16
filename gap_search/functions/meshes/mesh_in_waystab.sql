--- Author: Johanna Stötzer
-- Sample Call: SELECT mesh_in_waystab(2, 2728965, 1, 'ways'::text);

--

CREATE OR REPLACE FUNCTION mesh_in_waystab(
    node_id bigint,
    way_id bigint,
    mesh_id bigint,
    ways_table text
) RETURNS void
AS $$

plpy.execute(
"""
 UPDATE """ + ways_table + """
 SET meshid_rightway = CASE
        WHEN (meshid_rightway IS NULL)
        AND (source = """ + str(node_id) + """)
        THEN """ + str(mesh_id) + """ ELSE meshid_rightway END,
 meshid_wrongway = CASE
        WHEN NOT (source = """ + str(node_id) + """)
        AND (meshid_wrongway IS NULL)
        AND (target= """ + str(node_id) + """)
        THEN """ + str(mesh_id) + """ ELSE meshid_wrongway END
 WHERE gid = """ + str(way_id) + """
""")

$$ LANGUAGE plpython3u;
