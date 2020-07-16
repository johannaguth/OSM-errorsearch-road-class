--- Author: Johanna Stötzer
-- Sample Call: SELECT next_way_in_mesh_cc(174910, 169003, 'ways_tasmania_noded'::text);

-- Gives the counterclockwise next way_id at an intersection

CREATE OR REPLACE FUNCTION next_way_in_mesh_cc(
  origin_way_id bigint,
  currentnode_id bigint,
  ways_table text
) RETURNS bigint
AS $$
import math

vertices_table = ways_table + "_vertices_pgr"

## Get intersection points of 1 m circle around current node
plpy.execute("SELECT circle_intersections(id, '" + ways_table + "'::text) FROM " + vertices_table + " WHERE id = " + str(currentnode_id))
## Get coordinates of the origin point on the 1m circle and of the current node
origin_xy = [float(plpy.execute("SELECT x FROM intersections WHERE way_id = " + str(origin_way_id))[0]["x"]), float(plpy.execute("SELECT y FROM intersections WHERE way_id = " + str(origin_way_id))[0]["y"])]
current_xy = [float(plpy.execute("SELECT ST_X(the_geom) AS x FROM " + vertices_table + " WHERE id = " + str(currentnode_id))[0]["x"]), float(plpy.execute("SELECT ST_Y(the_geom) AS y FROM " + vertices_table + " WHERE id = " + str(currentnode_id))[0]["y"])]
plpy.execute("DELETE FROM intersections WHERE way_id = " + str(origin_way_id))

## Transform origin point so that the current point is 0|0 in the new coordinate system
origin_xy_trans = [origin_xy[0]-(current_xy[0]), origin_xy[1]-(current_xy[1])]
## Calculate the angle that the coordinate system will be rotated around
alpha = float(plpy.execute("SELECT calc_alpha(" + str(origin_xy_trans[0]) + ", " + str(origin_xy_trans[1]) + ") ")[0]["calc_alpha"])

## First calculate the new coordinates for all points, then calculate the angle of these point in respect to the original point
plpy.execute("ALTER TABLE intersections ADD COLUMN x_new2 double precision, ADD COLUMN y_new2 double precision, ADD COLUMN alpha_degree double precision")
if current_xy[0] >= 0:
	query = "UPDATE intersections SET x_new2 = (x-" + str(current_xy[0]) + ") * cos(" + str(alpha) + ") + (y - (" + str(current_xy[1]) + ")) * sin(" + str(alpha) + "),  y_new2 =  (-1) * (x-" + str(current_xy[0]) + ") * sin(" + str(alpha) + ") + (y - (" + str(current_xy[1]) + ")) * cos(" + str(alpha) + ")"
else:
	query = "UPDATE intersections SET x_new2 = (x+" + str(current_xy[0])[1:] + ") * cos(" + str(alpha) + ") + (y - (" + str(current_xy[1]) + ")) * sin(" + str(alpha) + "), y_new2= (-1) * (x+" + str(current_xy[0])[1:] + ") * sin(" + str(alpha) + ") + (y - (" + str(current_xy[1]) + ")) * cos(" + str(alpha) + ") "
#plpy.info(query)
plpy.execute(query)
plpy.execute("UPDATE intersections SET alpha_degree = calc_alpha(x_new2, y_new2) * (180.0 / " + str(math.pi)+")")

## Select the way_id with the lowest alpha as return value
way_id = int(plpy.execute("SELECT way_id FROM intersections WHERE alpha_degree = (SELECT min(alpha_degree) FROM intersections)")[0]["way_id"])
plpy.execute("DROP TABLE IF EXISTS intersections")

return way_id

$$ LANGUAGE plpython3u;
