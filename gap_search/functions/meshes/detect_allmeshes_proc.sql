--- Author: Johanna Stötzer
-- Sample Call: CALL detect_allmeshes('mesh_id'::text, 'ways_tasmania_noded'::text);

--

CREATE OR REPLACE PROCEDURE detect_allmeshes(
  mesh_id_text text,
  ways_table text
)
LANGUAGE plpython3u
AS $$

import time

tic = time.time()

vertices_table = ways_table + "_vertices_pgr"

# Selecting all node_ids in vertices table
node_ids = plpy.execute("SELECT id FROM " + vertices_table ) ## + " WHERE id = 56797")
node_ids_list= []
for i in node_ids:
	node_ids_list.append(int(i['id']))

# Loop over all node ids
for node_id in node_ids_list:
	plpy.info("Searching meshes for node: " + str(node_id))
	gids = plpy.execute("SELECT gid FROM " + ways_table + " WHERE source = " + str(node_id) + " OR target = " + str(node_id))
	gids_list= []
	for i in gids:
		gids_list.append(int(i['gid']))

	# Loop over all roads at one node
	for way_id in gids_list:
		mesh_id = int(plpy.execute("SELECT nextval('" + mesh_id_text + "')")[0]["nextval"])
		#plpy.info("Beginning with way id: " + str(way_id)) ###
		## Check if there already is a mesh_id in this direction of the way if yes: end function
		count = int(plpy.execute(
			"""
			WITH tab AS (
				SELECT gid, source, target,
					CASE WHEN source = """ + str(node_id) + """
						THEN TRUE
						WHEN target = """ + str(node_id) + """
						THEN FALSE END
				FROM """ + ways_table + """
				WHERE gid = """ + str(way_id) + """)
			SELECT
				CASE WHEN tab.case = TRUE
					THEN (SELECT COUNT(*)
						FROM """ + ways_table + """
						WHERE meshid_rightway IS NOT NULL
							AND gid = """ + str(way_id) + """)
					WHEN tab.case = FALSE
					THEN (SELECT COUNT(*)
						FROM """ + ways_table + """
						WHERE meshid_wrongway IS NOT NULL
							AND gid = """ + str(way_id) + """) END
			FROM tab
			""")[0]["case"])
		if count == 0:
			## Insert mesh gid into first way
			plpy.execute("SELECT mesh_in_waystab(" + str(node_id) + ", " + str(way_id) + ", " + str(mesh_id) + ", '" + ways_table + "'::text)")
			next_node = int(plpy.execute("SELECT gid, source, target, CASE WHEN source = " + str(node_id) + " THEN target WHEN target = " + str(node_id) + " THEN source END FROM " + ways_table + " WHERE gid = " + str(way_id))[0]["case"])
			next_way = way_id
			#plpy.info(next_way)
			count = 0
			## Loop the mesh and search for the next way_id
			while next_node != node_id:
				count += 1
				##plpy.info(next_way) ###
				cnt = int(plpy.execute("SELECT cnt FROM " + vertices_table + " WHERE id = " + str(next_node))[0]["cnt"])
				if cnt == 1:
					new_way_id = int(plpy.execute("SELECT gid FROM " + ways_table + " WHERE source = " + str(next_node) + " OR target = " + str(next_node))[0]["gid"])
				elif cnt == 2:
					new_way_id = int(plpy.execute("SELECT gid FROM " + ways_table + " WHERE (source = " + str(next_node) + " OR target = " + str(next_node) + ") AND NOT gid = " + str(next_way))[0]["gid"])
				elif cnt > 2:
					new_way_id = int(plpy.execute("SELECT next_way_in_mesh_cc(" + str(next_way) + ", " + str(next_node) + ", '" + ways_table + "'::text) AS gid")[0]["gid"])
				next_way = new_way_id
				plpy.execute("SELECT mesh_in_waystab(" + str(next_node) + ", " + str(next_way) + ", " + str(mesh_id) + ", '" + ways_table + "'::text)")
				next_node = int(plpy.execute("SELECT gid, source, target, CASE WHEN source = " + str(next_node) + " THEN target WHEN target = " + str(next_node) + " THEN source END FROM " + ways_table + " WHERE gid = " + str(next_way))[0]["case"])
				if count%1000 == 0:
					plpy.commit()
					plpy.info(str(count) + " committed")
	plpy.commit()

toc = time.time()

plpy.info('Procedure detect_allmeshes_proc() took ' + str(toc - tic) + ' seconds.')

$$;
