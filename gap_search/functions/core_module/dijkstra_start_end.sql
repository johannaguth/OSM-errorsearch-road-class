--- Author: Johanna Stötzer
-- Finds all deadends on one level that do not exist on the complete graph
-- Sample Call: SELECT dijkstra_start_end(110000,2025198, 'length_m'::text, 'ways_nsw'::text);
-- Last Change:
-- TODO: Integrate levels underneath

DROP TYPE IF EXISTS path_cost;
CREATE TYPE path_cost AS (
		start_vid integer,
		end_vid integer,
    pathdist       double precision,
    path       integer[]
);

CREATE OR REPLACE FUNCTION dijkstra_start_end(
	startnode bigint,
	endnode bigint,
	cost_col text,
	ways_table text
) RETURNS path_cost
AS $$
	result = plpy.execute("WITH dijkstra AS (SELECT * FROM pgr_dijkstra('SELECT gid AS id, source, target, " + cost_col + " AS cost, " + cost_col + " AS reverse_cost FROM " + ways_table + "', " + str(startnode) + ", " + str(endnode) + ")) SELECT SUM(dijkstra.cost), ARRAY(SELECT edge FROM dijkstra) FROM dijkstra")

	plpy.info("Distance calculated from " + str(startnode) + " to " + str(endnode) + ": " + str(result[0]["sum"]))

	return (startnode, endnode, result[0]["sum"], result[0]["array"])

$$ LANGUAGE plpython3u;

-- pathdist = float(plpy.execute("SELECT pgr_dijkstraCost('SELECT gid AS id, source, target, length_m AS cost, length_m AS reverse_cost FROM " + ways_table + "', " + str(startnode) + ", " + str(endnode) + ")")[0]["pgr_dijkstracost"]["agg_cost"])
-- plpy.info("Distance calculated from " + str(startnode) + " to " + str(endnode) + ": " + str(pathdist))
-- return pathdist

--WITH dijkstra AS (SELECT * FROM pgr_dijkstra('SELECT gid AS id, source, target, length_m AS cost, length_m AS reverse_cost FROM ways_nsw ', 110000, 2025198)) SELECT SUM(dijkstra.cost), ARRAY(SELECT node FROM dijkstra) FROM dijkstra;
