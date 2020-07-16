--- Author: Johanna Stötzer
-- Sample Call: SELECT cut_line(70, 'intergeom1'::text, 'ways_tasmania_noded'::text);

-- Requirement: table with geometries of cut points, ways the cut points lie on, ids of the cut points in vertices table and unique id
-- 				edge table

CREATE OR REPLACE FUNCTION cut_line(
  id bigint,
  cutpoint_table text,
  edge_table text
) RETURNS void
AS $$

vertices_table = edge_table + "_vertices_pgr"

plpy.execute("""INSERT INTO """ + edge_table + """  
	(class_id, length,  length_m,  name,  source,  target,  maxspeed_forward, maxspeed_backward, priority,  the_geom, former_way_id)
	WITH split_line AS (
	SELECT 
	(ST_LineSubstring(""" + edge_table + """.the_geom, 0, ST_LineLocatePoint(""" + edge_table + """.the_geom, """ + cutpoint_table + """.geom_clPt))) AS split_geom,
	""" + cutpoint_table + """.way_id,
	""" + cutpoint_table + """.vertice_id
	FROM """ + edge_table + """, """ + cutpoint_table + """
	WHERE  """ + cutpoint_table + """.id = """ + str(id) + """ AND """ + edge_table + """.gid = """ + cutpoint_table + """.way_id)
	SELECT class_id, ST_Length(split_line.split_geom), ST_Length(split_line.split_geom::geography),name, source, split_line.vertice_id,maxspeed_forward, maxspeed_backward, priority, split_line.split_geom, gid
	FROM """ + edge_table + """, split_line
	WHERE """ + edge_table + """.gid = split_line.way_id
	"""
	)

plpy.execute("""INSERT INTO """ + edge_table + """  
	(class_id, length,  length_m,  name,  source,  target,  maxspeed_forward, maxspeed_backward, priority,  the_geom, former_way_id)
	WITH split_line AS (
	SELECT 
	(ST_LineSubstring(""" + edge_table + """.the_geom, ST_LineLocatePoint(""" + edge_table + """.the_geom, """ + cutpoint_table + """.geom_clPt),1)) AS split_geom,
	""" + cutpoint_table + """.way_id,
	""" + cutpoint_table + """.vertice_id
	FROM """ + edge_table + """, """ + cutpoint_table + """
	WHERE  """ + cutpoint_table + """.id = """ + str(id) + """ AND """ + edge_table + """.gid = """ + cutpoint_table + """.way_id)
	SELECT class_id, ST_Length(split_line.split_geom), ST_Length(split_line.split_geom::geography),name, split_line.vertice_id, target,maxspeed_forward, maxspeed_backward, priority, split_line.split_geom, gid
	FROM """ + edge_table + """, split_line
	WHERE """ + edge_table + """.gid = split_line.way_id
	"""
	)


$$ LANGUAGE plpython3u;
