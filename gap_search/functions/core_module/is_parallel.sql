--- Author: Johanna Guth
-- Calculates if a pair of start_end points lies on parallel roads
-- Sample Call: SELECT is_parallel('ways_nsw_l3_noded'::text, 1392615, 1393957, 24);
-- Last Change:


CREATE OR REPLACE FUNCTION is_parallel(
	ways_table text,
  	start_vid bigint,
	end_vid bigint,
  	eucldist double precision
	) RETURNS boolean
AS $$

	vertices_table = ways_table + "_vertices_pgr"

	if eucldist > 100:
		return False
	else:
		start_ways = plpy.execute("SELECT gid FROM " + ways_table + " WHERE source = " + str(start_vid) + " OR target = " + str(start_vid))
		end_ways = plpy.execute("SELECT gid FROM " + ways_table + " WHERE source = " + str(end_vid) + " OR target = " + str(end_vid))
		count_p = 0
		for id in start_ways:
			endpoint_id = plpy.execute("SELECT (CASE WHEN source = " + str(start_vid) + " THEN target WHEN target = " + str(start_vid) + " THEN source END) as epid FROM " + ways_table + " WHERE gid = " + str(id['gid']))[0]['epid']
			for j in end_ways:
				lengths = plpy.execute("SELECT (SELECT length_m FROM " + ways_table + " WHERE gid =  " + str(id['gid']) + ") AS length1, (SELECT length_m FROM " + ways_table + " WHERE gid =  " + str(j['gid']) + ") AS length2")
				if lengths[0]['length1'] <= lengths[0]['length2']:
					distance = plpy.execute("SELECT st_distance(" + vertices_table + ".the_geom::geography, " + ways_table + ".the_geom::geography) AS dist FROM " + vertices_table + ", " + ways_table + " WHERE id = " + str(endpoint_id) + " AND gid = " + str(j['gid']))[0]['dist']
					if distance < eucldist + eucldist * 0.5:
						count_p += 1
				else:
					endpoint2_id = plpy.execute("SELECT (CASE WHEN source = " + str(end_vid) + " THEN target WHEN target = " + str(end_vid) + " THEN source END) as epid FROM " + ways_table + " WHERE gid = " + str(j['gid']))[0]['epid']
					distance = plpy.execute("SELECT st_distance(" + vertices_table + ".the_geom::geography, " + ways_table + ".the_geom::geography) AS dist FROM " + vertices_table + ", " + ways_table + " WHERE id = " + str(endpoint2_id) + " AND gid = " + str(id['gid']))[0]['dist']
					if distance < eucldist + eucldist * 0.5:
						count_p += 1
		if count_p >= 2:
			return True
		else:
			return False



$$ LANGUAGE plpython3u;

-- SELECT st_distance(ways_nsw_l3_noded_vertices_pgr.the_geom::geography, ways_nsw_l3_noded.the_geom::geography) AS dist FROM ways_nsw_l3_noded_vertices_pgr, ways_nsw_l3_noded WHERE id = 1805843 AND gid = 2042936;
