--- Author: Johanna Stötzer
-- Sample Call: CALL meshes_around_node(445, 'mesh_id'::text, 'ways_tasmania_noded'::text);

--

CREATE OR REPLACE PROCEDURE meshes_around_node(
  node_id bigint,
  mesh_id text,
  ways_table text
) 
LANGUAGE plpython3u
AS $$

vertices_table = ways_table + "_vertices_pgr"

plpy.info("Searching meshes for node: " + str(node_id))
gids = plpy.execute("SELECT gid FROM " + ways_table + " WHERE source = " + str(node_id) + " OR target = " + str(node_id))
gids_list= []
for i in gids:
	gids_list.append(int(i['gid']))

for i in gids_list:
	plpy.execute("CALL detect_one_mesh(" + str(node_id) + "::bigint, " + str(i) + ", nextval('" + mesh_id + "'), '" + ways_table + "'::text)")

$$;
