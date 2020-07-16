--- Author: Johanna Stötzer
-- Sample Call: SELECT mult_vertices_to_one('ways_tasmania_noded'::text);
-- Includes a crappy quick fix for 3 vertices --> does not detect 3 vertices on one spot

--

CREATE OR REPLACE FUNCTION mult_vertices_to_one(
    edge_table text
) RETURNS void
AS $$

vertices_table = edge_table + "_vertices_pgr"

## Crappy fix for 3 vertices
if edge_table == 'ways_nsw_noded':
	plpy.execute("DELETE FROM ways_nsw_noded_vertices_pgr WHERE id = 1751188 OR id = 2316552")
	plpy.execute("UPDATE ways_nsw_noded SET source = 2310172 WHERE source = 1751188 OR source = 2316552")
	plpy.execute("UPDATE ways_nsw_noded SET target = 2310172 WHERE target = 1751188 OR target = 2316552")
	plpy.info("Crappy fix done")
	
plpy.execute("DROP TABLE IF EXISTS pairs")
plpy.execute("CREATE TEMP TABLE pairs AS (SELECT a.id AS v1id, b.id AS v2id FROM " + vertices_table + " AS a, " + vertices_table + " AS b WHERE a.the_geom && b.the_geom AND ST_Equals(a.the_geom, b.the_geom) AND a.id <> b.id)")
plpy.execute("DROP TABLE IF EXISTS selected_vertice") 
plpy.execute("CREATE TEMP TABLE selected_vertice(vertice_id bigint, wrong_vid bigint)")
plpy.execute("SELECT delete_duppoints(v1id, v2id) FROM pairs")
plpy.execute("UPDATE " + edge_table + " SET source = selected_vertice.vertice_id FROM selected_vertice WHERE selected_vertice.wrong_vid = source")
plpy.execute("UPDATE " + edge_table + " SET target = selected_vertice.vertice_id FROM selected_vertice WHERE selected_vertice.wrong_vid = target")
plpy.execute("DELETE FROM " + vertices_table + " WHERE id IN (SELECT wrong_vid FROM selected_vertice)")
plpy.execute("DROP TABLE IF EXISTS selected_vertice")
	

$$ LANGUAGE plpython3u;
