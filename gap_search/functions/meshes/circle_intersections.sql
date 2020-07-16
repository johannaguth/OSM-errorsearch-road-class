--- Author: Johanna Stötzer
-- Sample Call: SELECT circle_intersections(id, 'ways'::text) FROM ways_vertices_pgr WHERE id = 2;

-- Creates a circle of x meter around a point which intersects the connecting lines --> calculates intersection points

CREATE OR REPLACE FUNCTION circle_intersections(
  node_id bigint,
  ways_table text,
  radius double precision default 0.1
) RETURNS void
AS $$

vertices_table = ways_table + "_vertices_pgr"

length = float(plpy.execute("SELECT MIN(length_m) AS min FROM " + ways_table + " WHERE source = " + str(node_id) + " OR target = " + str(node_id))[0]["min"])
#plpy.info(length)
if length <= radius:
	radius1 = length/2
elif node_id == 1862275 or node_id == 2270183:
	radius1 = 0.01
else:
	radius1 = radius
query = """CREATE TABLE intersections AS(
 WITH circles as (
    SELECT id as node_id, ST_ExteriorRing(st_buffer(the_geom::geography, """ + str(radius1) + """)::geometry) as circle
    FROM """ + vertices_table + """
    WHERE id = """ + str(node_id) + """
    ),
    sel_ways AS (
    SELECT * FROM """ + ways_table + """ WHERE source = """ + str(node_id) + """ OR target = """ + str(node_id) + """
    ),
    points as(
    SELECT circles.node_id, sel_ways.gid as way_id, st_intersection(circles.circle, sel_ways.the_geom) AS intersection
    FROM circles, sel_ways)
SELECT points.node_id, points.way_id, ST_X(intersection) AS x, ST_Y(intersection) AS y, intersection
FROM points)
"""
plpy.execute(query)
#plpy.info(plpy.execute("SELECT * FROM intersections"))

$$ LANGUAGE plpython3u;
