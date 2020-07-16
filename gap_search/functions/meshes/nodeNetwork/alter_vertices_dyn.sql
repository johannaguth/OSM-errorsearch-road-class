--- Author: Johanna Stötzer
-- Sample Call: SELECT alter_vertices('settlements_03'::text, 'city_nearest_nodes_on_way'::text, 'ways_vertices_pgr'::text);
-- 18.04978611866633 min for region maule

-- Changelog:
-- 10.07.17 Added CASCADE to all DROP TABLE statements

CREATE OR REPLACE FUNCTION alter_vertices(
	input_points text,
	points_nearest_nodes text,
	vertices_table text
	) RETURNS void
	
AS $$

DECLARE
affected_rows int8;
StartTime timestamptz;
EndTime timestamptz;
Delta float;

BEGIN
	StartTime := clock_timestamp();
	DROP TABLE IF EXISTS vertices_with_cities CASCADE;
	EXECUTE format(
		'CREATE TABLE vertices_with_cities AS '
			'SELECT %1$I.*, %2$I.id AS vc_id '
			'FROM %1$I, %2$I '
			'WHERE %1$I.geom_clpt && %2$I.the_geom OR ST_Intersects(%1$I.geom_clpt,%2$I.the_geom) '
		, points_nearest_nodes, vertices_table);
	
	CREATE INDEX vertices_with_cities_GIST ON vertices_with_cities USING GIST (geom_clPt);
	
	EXECUTE format(
		'UPDATE %1$I '
			'SET node_id = vertices_with_cities.vc_id '
			'FROM %2$I, vertices_with_cities '
			'WHERE %2$I.id = vertices_with_cities.vc_id '
			'AND %1$I.osm_id = vertices_with_cities.settlement_id '
		, input_points, vertices_table);
	
	EXECUTE format(
		'UPDATE %1$I '
			'SET node_dist = vertices_with_cities.dist '
			'FROM vertices_with_cities '
			'WHERE %1$I.node_id = vertices_with_cities.vc_id '
			'AND %1$I.osm_id = vertices_with_cities.settlement_id '
		, input_points);
	
	GET DIAGNOSTICS affected_rows = ROW_COUNT;
	RAISE NOTICE 'UPDATED vertices with points: %', affected_rows;
	
	EXECUTE format(
		'DELETE FROM %1$I WHERE %1$I.settlement_id IN (SELECT vertices_with_cities.settlement_id FROM vertices_with_cities) '
	, points_nearest_nodes);
	
	GET DIAGNOSTICS affected_rows = ROW_COUNT;
	RAISE NOTICE 'DELETED vertices with points: %', affected_rows;
	
	-- Problem with two vertices on the same spot:
	EXECUTE format('SELECT detect_multiple_points(''%1$I''::text)', points_nearest_nodes);
	
	-- Insert vertices in vertice table
	EXECUTE format(
		'INSERT INTO %2$I(lon, lat, the_geom) '
			'SELECT ' 
				'ST_X (ST_Transform (geom_clPt, 4326)), '
				'ST_Y (ST_Transform (geom_clPt, 4326)), '
				'geom_clPt '
			'FROM %1$I'
	, points_nearest_nodes, vertices_table);
	
	GET DIAGNOSTICS affected_rows = ROW_COUNT;
	RAISE NOTICE 'INSERTED vertices in vertices table: %', affected_rows;
	
	-- Update node_id for settlements
	EXECUTE format(
		'UPDATE %2$I '
			'SET node_id = %3$I.id '
			'FROM %3$I, %1$I '
			'WHERE %3$I.the_geom ~= %1$I.geom_clPt '
			'AND %1$I.settlement_id = %2$I.osm_id '
	, points_nearest_nodes, input_points, vertices_table);
	
	GET DIAGNOSTICS affected_rows = ROW_COUNT;
	RAISE NOTICE 'Updated node_id in input_points: %', affected_rows;
	
	-- Update node_dist for settlements	
	EXECUTE format(
		'UPDATE %2$I '
			'SET node_dist = %1$I.dist '
			'FROM %1$I '
			'WHERE %1$I.settlement_id = %2$I.osm_id '
	, points_nearest_nodes, input_points);

	GET DIAGNOSTICS affected_rows = ROW_COUNT;
	RAISE NOTICE 'Updated node_dist in input_points: %', affected_rows;

	-- Update node_id for cities with multiple on same spot
	EXECUTE format( 
		'WITH settlement_data AS( '
				'SELECT %1$I.node_id, node_on_way_with_multiple_points.dist, node_on_way_with_multiple_points.settlement_id '
				'FROM %1$I, node_on_way_with_multiple_points '
				'WHERE %1$I.osm_id = node_on_way_with_multiple_points.nn1_osm_id) '
		
			'UPDATE %1$I '
			'SET node_id = settlement_data.node_id '
			'FROM settlement_data '
			'WHERE %1$I.osm_id = settlement_data.settlement_id '
	, input_points);
	
	GET DIAGNOSTICS affected_rows = ROW_COUNT;
	RAISE NOTICE 'Updated input_points node_id for two points on the same spot: %', affected_rows;
	
	-- Update node_dist for cities with multiple on same spot
	EXECUTE format( 
		'WITH settlement_data AS( '
				'SELECT %1$I.node_id, node_on_way_with_multiple_points.dist, node_on_way_with_multiple_points.settlement_id '
				'FROM %1$I, node_on_way_with_multiple_points '
				'WHERE %1$I.osm_id = node_on_way_with_multiple_points.nn1_osm_id) '
		
			'UPDATE %1$I '
			'SET node_dist = settlement_data.dist '
			'FROM settlement_data '
			'WHERE %1$I.osm_id = settlement_data.settlement_id '
	, input_points);
	
	GET DIAGNOSTICS affected_rows = ROW_COUNT;
	RAISE NOTICE 'Updated input_points node_dist for two points on the same spot: %', affected_rows;
	
		
	-- Filling in seq column that numbers the ways which have to be split multiple times
	EXECUTE format(
		'UPDATE %1$I '
		'SET seq = cit.seq1 '
		'FROM ( '
			'SELECT '
				'city.id, '
				'city.way_id, '
				'(SELECT count(*) FROM %1$I AS city2 WHERE city2.way_id = city.way_id AND city2.id <= city.id) AS seq1 '
			'FROM %1$I AS city '
			'ORDER BY city.id '
			') AS cit '
		'WHERE %1$I.id = cit.id ' 
	, points_nearest_nodes);
	
	EndTime := clock_timestamp();
  	Delta := ( extract(epoch from EndTime) - extract(epoch from StartTime) );
	RAISE NOTICE 'Duration of alter_vertices in millisecs=%1, seconds =%2, minutes=%3', Delta * 1000, Delta, Delta/60 ;	
END;
$$ LANGUAGE 'plpgsql';



