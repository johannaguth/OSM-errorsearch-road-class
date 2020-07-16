--- Author: Johanna Stötzer
-- Sample Call: SELECT delete_duppoints(v1id, v2id) FROM pairs;

--

CREATE OR REPLACE FUNCTION delete_duppoints(
  v1id bigint,
  v2id bigint
  
) RETURNS void
AS $$
	plpy.execute("""INSERT INTO selected_vertice (vertice_id, wrong_vid) 
		SELECT v1id, v2id
		FROM pairs
		WHERE v1id = """ + str(v1id) + """ AND v2id = """ + str(v2id) + """ AND v1id NOT IN (SELECT wrong_vid FROM selected_vertice WHERE vertice_id = """ + str(v2id) + """)
		""")
$$ LANGUAGE plpython3u;

