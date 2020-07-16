--- Author: Johanna Stötzer
-- Sample Call: CALL dijkstra_allmeshes('ways_nsw_l4_noded'::text, 'ways_nsw_noded'::text, 'length_m'::text, 'vertices_meshes_nsw_l4'::text, 'od_pathdist_eucldist_nsw_l4'::text, FALSE);
-- Last Change: 26.11. changed end points to only the ones with different cnt
--

CREATE OR REPLACE PROCEDURE dijkstra_allmeshes(
  ways_table text,
  all_ways text,
  cost_col text,
  mesh_nodeids text,
  result_table text,
  deadends boolean DEFAULT FALSE,
  deadend_table text DEFAULT 'NULL'
)
LANGUAGE plpython3u
AS $$

import time

tic = time.time()
# Asking if source is a table of deadends or if it is a normal vertices_table
if deadend_table == 'NULL':
    vertices_table = ways_table + "_vertices_pgr"
else:
    vertices_table = deadend_table
all_vertices = all_ways + "_vertices_pgr"

# Selecting all node_ids in vertices table with a cnt different from original ways table and not cnt >1 on motorways and trunks
if deadends == True :
    node_ids = plpy.execute("SELECT DISTINCT " + vertices_table + ".id FROM " + vertices_table)
else:
    node_ids = plpy.execute("SELECT DISTINCT " + vertices_table + ".id FROM " + vertices_table + ", " + all_vertices + ", " + ways_table + " WHERE (" + vertices_table + ".cnt != " + all_vertices + ".cnt AND " + vertices_table + ".id = " + all_vertices + ".id) AND ((" + vertices_table + ".id = " + ways_table + ".source OR " + vertices_table + ".id = " + ways_table + ".target) AND NOT ((" + ways_table + ".class_id = 101 OR " + ways_table + ".class_id = 104) AND " + vertices_table + ".cnt > 1)) ")# AND ways_nsw_l3_noded_vertices_pgr.id = 125301 ")
node_ids_list= []
for i in node_ids:
	node_ids_list.append(int(i['id']))

# Selecting the outer meshid (mesh with most roads) to exclude it from calculation
outermesh = int(plpy.execute("SELECT meshid, COUNT (*) FROM " + mesh_nodeids + " GROUP BY meshid ORDER BY count DESC LIMIT 1")[0]['meshid'])

for node_id in node_ids_list:
	plpy.info("calculating shortest paths for node: " + str(node_id))
  ### count = how many target points for this node_id
	count_nodes = int(plpy.execute("SELECT count(id) FROM " + mesh_nodeids + ", " + ways_table + " WHERE meshid IN (SELECT meshid FROM " + mesh_nodeids + " WHERE id = " + str(node_id) + " AND meshid != " + str(outermesh) + ") AND (" + mesh_nodeids + ".id = source OR " + mesh_nodeids + ".id = target)")[0]['count'])
	if count_nodes > 0 : ## falls mehr als 0 target points --> routen berechnen
		plpy.execute("INSERT INTO " + result_table + "(start_vid, end_vid, agg_cost) " +
			"SELECT start_vid, end_vid, agg_cost FROM pgr_dijkstraCost('SELECT gid AS id, source, target, " + cost_col + " AS cost, " + cost_col + " AS reverse_cost FROM "
			+ ways_table + "', " + str(node_id) + ", array(SELECT " + mesh_nodeids + ".id FROM " + vertices_table + ", " + all_vertices + ", " + mesh_nodeids + ", " + ways_table + " WHERE meshid IN (SELECT meshid FROM " + mesh_nodeids + " WHERE id = " + str(node_id) + " AND meshid != " + str(outermesh) + ") AND (" + mesh_nodeids + ".id = source OR " + mesh_nodeids + ".id = target) AND " + mesh_nodeids + ".id = " + vertices_table + ".id AND " + mesh_nodeids + ".id = " + all_vertices + ".id AND " + all_vertices + ".cnt != " + vertices_table + ".cnt),false)")
		plpy.commit()


toc = time.time()

plpy.info('Procedure dijkstra_allmeshes() took ' + str(toc - tic) + ' seconds.')

$$;


  -- plpy.execute("INSERT INTO " + result_table + "(start_vid, end_vid, agg_cost) " +
  --   "SELECT start_vid, end_vid, agg_cost FROM pgr_dijkstraCost('SELECT gid AS id, source, target, " + cost_col + " AS cost, " + cost_col + " AS reverse_cost FROM "
  --   + ways_table + "', " + str(node_id) + ", array(SELECT id FROM " + mesh_nodeids + ", " + ways_table + " WHERE meshid IN (SELECT meshid FROM " + mesh_nodeids + " WHERE id = " + str(node_id) + " AND meshid != " + str(outermesh) + ") AND (" + mesh_nodeids + ".id = source OR " + mesh_nodeids + ".id = target)),false)")

-- SELECT start_vid, end_vid, agg_cost FROM pgr_dijkstraCost('SELECT gid AS id, source, target, length_m AS cost, length_m AS reverse_cost FROM ways_nsw_l4_noded', 560216, 680105 ,false);
-- SELECT  ways_nsw_l3_noded_vertices_pgr.id
-- FROM ways_nsw_l3_noded_vertices_pgr, ways_nsw_noded_vertices_pgr, ways_nsw_l3_noded
-- WHERE
--   (
--      ways_nsw_l3_noded_vertices_pgr.cnt != ways_nsw_noded_vertices_pgr.cnt
--      AND ways_nsw_l3_noded_vertices_pgr.id = ways_nsw_noded_vertices_pgr.id
--   ) LIMIT 20;
--   AND
--   (
--     (ways_nsw_l3_noded_vertices_pgr.id = ways_nsw_l3_noded.source OR ways_nsw_l3_noded_vertices_pgr.id = ways_nsw_l3_noded.target)
--     AND NOT
--     (
--       (ways_nsw_l3_noded.class_id = 101 OR ways_nsw_l3_noded.class_id = 104)
--       AND ways_nsw_l3_noded_vertices_pgr.cnt > 1
--     )
--   )
-- LIMIT 20;
