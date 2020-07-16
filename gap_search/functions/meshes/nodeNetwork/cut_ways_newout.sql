--- Author: Johanna Stötzer
-- Sample Call: SELECT cut_ways_newout('city_nearest_nodes_on_way'::text, 'ways_vertices_pgr'::text, 'ways'::text);
-- 33.56 min for region

-- Changelog:
-- 10.07.17 Added CASCADE to all DROP TABLE statements

CREATE OR REPLACE FUNCTION cut_ways_newout(
	points_nearest_nodes text,
	noded_ways text
	) RETURNS void
AS $$ 

DECLARE
max int;
count int;
max_seq int;
affected_rows int;
StartTime timestamptz;
EndTime timestamptz;
Delta float;
noded_vertices text;

BEGIN
	StartTime := clock_timestamp();
	
	noded_vertices := noded_ways || '_vertices_pgr';
	
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
	
	-- Insert vertices in vertice table
	 EXECUTE format(
		'INSERT INTO %2$I(lon, lat, the_geom) '
			'SELECT ' 
				'ST_X (ST_Transform (geom_clPt, 4326)), '
				'ST_Y (ST_Transform (geom_clPt, 4326)), '
				'geom_clPt '
			'FROM %1$I '
	, points_nearest_nodes, noded_vertices);
	
	ALTER TABLE intergeom1 ADD COLUMN IF NOT EXISTS vertice_id bigint;
	EXECUTE format( 'UPDATE intergeom1 SET vertice_id = %1$I.id '
	'FROM %1$I '
	'WHERE %1$I.the_geom = %2$I.geom_clPt', noded_vertices, points_nearest_nodes);
	
	DROP TABLE IF EXISTS created_ways CASCADE;
	CREATE TABLE created_ways(
	way_id int,
	former_way_id int);
	
	EXECUTE format('ALTER TABLE %1$I DROP COLUMN IF EXISTS former_way_id', noded_ways);
	EXECUTE format('ALTER TABLE %1$I ADD COLUMN former_way_id int', noded_ways);
	
	EXECUTE format('SELECT COUNT(id) FROM %1$I', points_nearest_nodes) INTO count;
	EXECUTE format('SELECT MAX(seq) FROM %1$I', points_nearest_nodes) INTO max_seq;
	
	IF count = 0 
		THEN max:= 0; 
	ELSE
		max := max_seq; 
		RAISE NOTICE 'Total number of loops: %', max;
		FOR i IN 1..max 
		LOOP
		--RAISE NOTICE 'begin loop for the % time', i;
				-- Insert split ways from source to settlement
			EXECUTE format('SELECT cut_line(id, ''%1$I''::text, ''%2$I''::text) FROM %1$I WHERE seq = $1 AND NOT (id = 70 OR id = 298)', points_nearest_nodes, noded_ways)
				USING i;
				
				GET DIAGNOSTICS affected_rows = ROW_COUNT;
				--RAISE NOTICE 'INSERTED ways on % loop: %', i, affected_rows;
				
				--RAISE NOTICE 'second insert done for the % time', i;
				
				EXECUTE FORMAT(	
					'INSERT INTO created_ways(way_id, former_way_id) '
					'SELECT %2$I.gid, %1$I.way_id '
					'FROM %2$I, %1$I '
					'WHERE %1$I.way_id = %2$I.former_way_id '
					'AND %1$I.seq = $1 '
				, points_nearest_nodes, noded_ways)
				USING i;
				
				--RAISE NOTICE 'insert into created_ways done for the % time', i;
			
					--DELETE FROM %2$I WHERE gid IN (SELECT former_way_id FROM created_ways);
				EXECUTE FORMAT(	
					'UPDATE %1$I '
					'SET way_id = new_way.new_way_id '
					'FROM  '
						'(WITH possib AS( '
							'SELECT   '
								'%1$I.id,  '
								'%1$I.geom_clPt, '
								'%1$I.seq, '
								'%2$I.* '
							'FROM %2$I, %1$I '
							'WHERE %2$I.former_way_id = %1$I.way_id '
							'AND %1$I.seq > $1 '
							')  '
						'SELECT possib.gid AS new_way_id, possib.id '
						'FROM possib '
						'WHERE ST_Intersects(possib.the_geom, ST_Buffer(possib.geom_clPt,0.00000001)) '
						') AS new_way '
					'WHERE %1$I.seq > $1 '
					'AND %1$I.id = new_way.id '
				, points_nearest_nodes, noded_ways)
				USING i;
					
				RAISE NOTICE 'end of loop for the % time', i;
			END LOOP; 
		END IF;
	

	-- Delete original ways from way table
	EXECUTE FORMAT('DELETE FROM %1$I WHERE gid IN (SELECT former_way_id FROM created_ways) ', noded_ways);


	-- DROP TABLE IF EXISTS created_ways CASCADE;
	DROP TABLE IF EXISTS node_on_way_with_2_cities CASCADE;
	DROP TABLE IF EXISTS vertices_with_cities CASCADE;

	EXECUTE FORMAT('SELECT pgr_analyzeGraph(''%1$I'',0.001,''the_geom'',''gid'')', noded_ways);
	EndTime := clock_timestamp();
  	Delta := ( extract(epoch from EndTime) - extract(epoch from StartTime) );
	RAISE NOTICE 'Duration of cut_ways in millisecs=%1, seconds =%2, minutes=%3', Delta * 1000, Delta, Delta/60 ;	
END;
$$ LANGUAGE 'plpgsql';



