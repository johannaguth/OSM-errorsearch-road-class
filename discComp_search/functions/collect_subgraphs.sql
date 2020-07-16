--- Author: Johanna Guth
-- creates multilines for all subgraphs
-- Sample Call: SELECT collect_subgraphs('ways_nsw_l3_noded'::text);
-- Last Change:  9.3. added descriptions


CREATE OR REPLACE FUNCTION collect_subgraphs(
	ways_table text
	) RETURNS void
AS $$

subgraph_table = ways_table + "_subgraphColl"
import time
tic = time.time()
vertices_table = ways_table + "_vertices_pgr"

plpy.execute("DROP TABLE IF EXISTS " + subgraph_table)
plpy.execute("CREATE TABLE " + subgraph_table + " AS (WITH ways_graphid AS( SELECT graph_id, gid, " + ways_table + ".the_geom AS geom FROM " + ways_table + ", " + vertices_table + " WHERE source = id ) SELECT graph_id, st_collect(geom) AS geom FROM ways_graphid GROUP BY graph_id)")

plpy.execute("ALTER TABLE " + subgraph_table + " ADD PRIMARY KEY (graph_id)")
plpy.execute("CREATE INDEX " + subgraph_table + "_gist ON " + subgraph_table + " USING GIST(geom)")
plpy.execute("ALTER TABLE " + subgraph_table + " ADD COLUMN error_type int")

toc = time.time()
plpy.info("Function collect_subgraphs for " + ways_table + " took " + str(toc - tic) + " seconds and created the table " + subgraph_table + ".")

$$ LANGUAGE plpython3u;
