	-- Gaps with meshsearch
	-- Current time (begin)
	SELECT CURRENT_TIME;
	
--- Calculate pathdistance on the level of road nework for every pair of Origin and Destination in one mesh and insert them in table od_pded
	DROP TABLE IF EXISTS od_pded_nsw_l4 CASCADE;
	CREATE TABLE od_pded_nsw_l4(id serial NOT NULL PRIMARY KEY, start_vid bigint, end_vid bigint, agg_cost double precision, eucldist double precision, agg_div_eucl double precision, agg_min_eucl double precision, geog_start geometry, geog_end geometry, start_end_multpoint geometry);

	CALL dijkstra_allmeshes('ways_nsw_l4'::text, 'ways_nsw'::text, 'length_m'::text, 'vertices_meshes_nsw_l4'::text, 'od_pded_nsw_l4'::text);

	---- Insert the start and end point geometries in od_pded and collect them in a multipoint
	UPDATE od_pded_nsw_l4 SET geog_start = the_geom FROM ways_nsw_l4_vertices_pgr WHERE ways_nsw_l4_vertices_pgr.id = start_vid;
	UPDATE od_pded_nsw_l4 SET geog_end = the_geom FROM ways_nsw_l4_vertices_pgr WHERE ways_nsw_l4_vertices_pgr.id = end_vid;
	UPDATE od_pded_nsw_l4 SET start_end_multpoint = ST_Collect(geog_start, geog_end);

	---- Create index on geometries
	CREATE INDEX geog_start_gist_l4 on od_pded_nsw_l4 USING GIST (geog_start);
	CREATE INDEX geog_end_gist_l4 on od_pded_nsw_l4 USING GIST (geog_end);
	CREATE INDEX start_end_multpoint_gist_l4 on od_pded_nsw_l4 USING GIST (start_end_multpoint);

	VACUUM ANALYZE od_pded_nsw_l4;
--- Calculate eucledian distance for all geometries and the ratio of Ed and Pd (G1)
	UPDATE od_pded_nsw_l4 SET eucldist = ST_Distance(geog_start::geography, geog_end::geography);
	UPDATE od_pded_nsw_l4 SET agg_div_eucl = agg_cost/eucldist;

--- FILTER 1: New table with only maximum agg_div_eucl per OD-pair
	DROP TABLE IF EXISTS od_tab_nsw_l4;
	CREATE TABLE od_tab_nsw_l4 AS (
		SELECT DISTINCT ON (start_vid) start_vid, end_vid, agg_cost, eucldist, agg_div_eucl, agg_min_eucl, start_end_multpoint FROM od_pded_nsw_l4 ORDER BY start_vid, agg_div_eucl DESC, end_vid);

	---- Add columns
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN alllevel_pathdist float;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN lev_div_alllev_pathdist float;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN lev_min_alllev_pathdist float;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN alllevel_path integer[];
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN count_intersec int;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN points_1 int;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN points_2 int;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN points_3 int;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN points_4 int;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN points_5 int;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN points_134 int;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN points_1345 int;
	ALTER TABLE od_tab_nsw_l4 ADD COLUMN points_12345 int;

--- Calculate Pd - Ed (G2)
	UPDATE od_tab_nsw_l4 SET agg_min_eucl = agg_cost - eucldist;

--- Count number of point pairs on the same spot -> G3 Parameter
	WITH count as (SELECT COUNT(od_tab_nsw_l4.*) as cnt, id FROM od_tab_nsw_l4, ways_nsw_l4_noded_vertices_pgr WHERE st_intersects (the_geom, start_end_multpoint) AND (id = od_tab_nsw_l4.start_vid OR id = od_tab_nsw_l4.end_vid) GROUP BY id)
	UPDATE od_tab_nsw_l4 SET count_intersec = count.cnt FROM count WHERE count.id = od_tab_nsw_l4.start_vid;

--- FILTER 2 (only keep OD pairs above the 70% quantile of G1 and above the 25% quantile of G2) and calculation of path on complete network
	WITH g1_quantile AS (
		SELECT percentile_disc(0.70) WITHIN GROUP (ORDER BY agg_div_eucl)  AS val
		FROM od_tab_nsw_l4),
	g2_quantile AS (
		SELECT percentile_disc(0.25) WITHIN GROUP (ORDER BY agg_min_eucl) AS val
		FROM od_tab_nsw_l4),
	dijkstra AS
		(SELECT dijkstra_start_end(start_vid, end_vid, 'length_m'::text, 'ways_nsw'::text) as result
		FROM od_tab_nsw_l4, g1_quantile, g2_quantile
		WHERE agg_div_eucl > g1_quantile.val  AND agg_min_eucl > g2_quantile.val)
		UPDATE od_tab_nsw_l4 SET alllevel_pathdist = (result).pathdist, alllevel_path = (result).path FROM dijkstra WHERE (result).start_vid = start_vid AND (result).end_vid = end_vid;

--- Calculate G4 and G5
	UPDATE od_tab_nsw_l4 SET lev_div_alllev_pathdist = agg_cost/alllevel_pathdist;
	UPDATE od_tab_nsw_l4 SET lev_min_alllev_pathdist = agg_cost-alllevel_pathdist;

--- Create new table with all OD-pairs where the complete path distance was calculated
	DROP TABLE IF EXISTS od_cand_l4 CASCADE;
	CREATE TABLE od_cand_l4 AS (SELECT start_vid, end_vid, agg_cost, eucldist, alllevel_path, alllevel_pathdist, count_intersec, agg_div_eucl, agg_min_eucl, lev_div_alllev_pathdist, lev_min_alllev_pathdist, points_1, points_2, points_3, points_4, points_5, points_134, points_1345, points_12345, start_end_multpoint FROM od_tab_nsw_l4 WHERE alllevel_pathdist IS NOT NULL);

	-- Apply rating system
	SELECT give_pointsquantile('od_cand_l4'::text, ARRAY[0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9], 'agg_div_eucl'::text, 'points_1'::text);
	SELECT give_pointsquantile('od_cand_l4'::text, ARRAY[0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9], 'agg_min_eucl'::text, 'points_2'::text);
	SELECT give_pointsvalues('od_cand_l4'::text, ARRAY[0,1,2,3,4,5,7,9,11,13,15], 'count_intersec'::text, 'points_3'::text);
	SELECT give_pointsquantile('od_cand_l4'::text, ARRAY[0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9], 'lev_div_alllev_pathdist'::text, 'points_4'::text);
	SELECT give_pointsquantile('od_cand_l4'::text, ARRAY[0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9], 'lev_min_alllev_pathdist'::text, 'points_5'::text);

--- Update rating combinations
	UPDATE od_cand_l4 SET points_134 = points_1 + points_3 + points_4;
	UPDATE od_cand_l4 SET points_1345 = points_1 + points_3 + points_4 + points_5;
	UPDATE od_cand_l4 SET points_12345 = points_1 + points_2 + points_3 + points_4 + points_5;

--- Delete OD-Pairs where O and D lie on parallel roads (roads with two lanes)
	DELETE FROM od_cand_l4 WHERE is_parallel('ways_nsw_l4_noded'::text,start_vid, end_vid, eucldist) = TRUE;

--- Cluster the OD Pairs in order to facilitate the checking of errors
	ALTER TABLE od_cand_l4 ADD COLUMN cid integer;
	WITH cluster AS (SELECT start_vid, end_vid, ST_clusterDBSCAN(start_end_multpoint, 0.05, 2) OVER () AS cid FROM od_cand_l4) UPDATE od_cand_l4 SET cid = cluster.cid FROM cluster WHERE cluster.start_vid = od_cand_l4.start_vid AND cluster.end_vid = od_cand_l4.end_vid;

--- Delete unused tables
DROP TABLE od_pded_nsw_l4 CASCADE;
DROP TABLE od_tab_nsw_l4 CASCADE;

-- Current time (end)
SELECT CURRENT_TIME;
