-- Author: Johanna Stötzer
-- Sample Call: SELECT detect_multiple_points('centroids_nearest_nodes_on_way_region'::text);
-- 6.605650734901433 min for ca 27000 Loops

-- Changelog:
-- 10.07.17 Added CASCADE to all DROP TABLE statements

CREATE OR REPLACE FUNCTION detect_multiple_points(
	points_nearest_nodes text
	) RETURNS VOID
AS $$

DECLARE
affected_rows int8;
max int8;
count_id int8;
i int8;
n int8;
StartTime timestamptz;
EndTime timestamptz;
Delta float;
rec RECORD;

BEGIN	
	StartTime := clock_timestamp();
	DROP TABLE IF EXISTS node_on_way_with_multiple_points CASCADE;
	
	CREATE TABLE node_on_way_with_multiple_points (
		id_pkey BIGSERIAL PRIMARY KEY,
		id int8,
		settlement_id int8,
		way_id int8,
		dist float8,
		geom_clpt geometry,
		seq int4,
		nn1_id int8,
		nn1_osm_id int8);
	
	DROP TABLE IF EXISTS dup CASCADE;
	EXECUTE format(
		'CREATE TABLE dup AS( '
			'SELECT nn1.id AS nn1_id, nn1.settlement_id AS nn1_osm_id, nn2.id  AS nn2_id, nn2.settlement_id AS nn2_osm_id '
			'FROM %1$I AS nn1 '
			'LEFT JOIN %1$I AS nn2 '
			'ON nn1.geom_clPt && nn2.geom_clPt '
			'WHERE nn1.id != nn2.id) '
	, points_nearest_nodes);
	
	DROP TABLE IF EXISTS dup2 CASCADE;
	CREATE TABLE dup2 AS (SELECT * FROM dup);
	
	n := 0;
	
	count_id := (SELECT COUNT(nn1_id) FROM dup);
	IF count_id > 0 THEN
		max := (SELECT COUNT(DISTINCT nn1_id) FROM dup);
		RAISE NOTICE 'Total Number of Loops: %', max;
		FOR rec IN SELECT DISTINCT nn1_id FROM dup2
		LOOP
		n := n + 1;
		i := (SELECT rec.nn1_id);
		count_id := (SELECT COUNT(nn1_id) FROM dup WHERE nn1_id = i);
		IF count_id > 0 THEN
			EXECUTE format(
				'INSERT INTO node_on_way_with_multiple_points (settlement_id, way_id, dist, geom_clpt, seq, id, nn1_id, nn1_osm_id)'
					'SELECT %1$I.*, dup.nn1_id, dup.nn1_osm_id '
					'FROM %1$I, dup '
					'WHERE dup.nn1_id = $1 '
					'AND dup.nn2_id = %1$I.id'
			, points_nearest_nodes) USING i;
	
			EXECUTE format('DELETE FROM dup WHERE nn1_id IN (SELECT nn2_id FROM DUP WHERE nn1_id = $1)',  points_nearest_nodes) USING i;		
		END IF;	
		IF n % 10000 = 0 THEN
			RAISE NOTICE 'Loop done for % times', n;
		END IF;
		END LOOP;
		
		EXECUTE format(
			'DELETE FROM %1$I WHERE %1$I.id IN (SELECT nn2_id FROM dup)'
		, points_nearest_nodes);
			GET DIAGNOSTICS affected_rows = ROW_COUNT;
		RAISE NOTICE 'DELETED vertices on the same spot: %', affected_rows;		
	END IF;	
	
	DROP TABLE IF EXISTS dup CASCADE;
	DROP TABLE IF EXISTS dup2 CASCADE;
	
	EndTime := clock_timestamp();
  	Delta := ( extract(epoch from EndTime) - extract(epoch from StartTime) );
  	RAISE NOTICE 'Duration of detect_multiple_points in millisecs=%1, seconds =%2, minutes=%3', Delta * 1000, Delta, Delta/60 ;	

END;
$$ LANGUAGE 'plpgsql';			
