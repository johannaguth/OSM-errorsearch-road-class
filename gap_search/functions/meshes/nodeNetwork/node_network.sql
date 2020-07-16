--- Author: Johanna Stötzer
-- Sample Call: SELECT node_network('ways_tasmania'::text);

--

CREATE OR REPLACE FUNCTION node_network(
  edge_table text,
  schema_name text
) RETURNS void

AS $$
vertices_table = edge_table + '_vertices_pgr'
noded_ways = edge_table + '_noded'
noded_vertices = noded_ways + '_vertices_pgr'
edge_table_withschema = schema_name + '.' + edge_table
edge_table_withschema_noded = schema_name + '.' + noded_ways

plpy.execute("DROP TABLE IF EXISTS " + noded_ways)
plpy.execute("DROP TABLE IF EXISTS " + noded_vertices)
plpy.execute("CREATE TABLE " + noded_ways + " (LIKE " + edge_table + " INCLUDING ALL)")
plpy.execute("INSERT INTO " + noded_ways + " SELECT * FROM " + edge_table + " WHERE NOT source = target")
plpy.execute("CREATE TABLE " + noded_vertices + " (LIKE " + vertices_table + " INCLUDING ALL)")
plpy.execute("INSERT INTO " + noded_vertices + " SELECT * FROM " + vertices_table)
plpy.execute("CREATE INDEX " + noded_ways + "_GIST ON " + noded_ways + " USING GIST (the_geom)")
plpy.execute("CREATE INDEX " + noded_vertices + "_GIST ON " + noded_vertices + " USING GIST (the_geom)")
plpy.info("2 Tables created: " + noded_ways + " and " + noded_vertices)
plpy.execute("DELETE FROM " + noded_vertices + " WHERE id NOT IN (SELECT source FROM " + noded_ways + ") AND id NOT IN (SELECT target FROM " + noded_ways + ")")
# Delete duplicate ways (OSM Errors)
plpy.execute("""DELETE FROM """ + noded_ways + """
	USING
		(SELECT w1.gid AS w1_gid, w1.source, w1.target, w2.gid as w2_gid, w2.source, w2.target
		FROM """ + noded_ways + """ AS w1, """ + noded_ways + """ AS w2
		WHERE ((w1.source = w2.source AND w1.target = w2.target) OR (w1.source = w2.target AND w1.target = w2.source)) AND w1.gid != w2.gid AND st_equals(w1.the_geom, w2.the_geom) AND w1.gid < w2.gid ORDER BY w1.gid ASC) AS delete
	WHERE """ + noded_ways + """.gid = delete.w1_gid""")
plpy.execute("SELECT create_intergeom('"+ edge_table_withschema_noded + "', 0, 'gid')")
plpy.execute("ALTER TABLE intergeom RENAME COLUMN l1id TO way_id")
plpy.execute("DROP TABLE IF EXISTS intergeom1")
plpy.execute("CREATE TABLE intergeom1 AS SELECT way_id, l2id, (ST_dump(geom)).geom AS geom_clPt FROM intergeom")
plpy.execute("ALTER TABLE intergeom1 ADD COLUMN id SERIAL PRIMARY KEY")
plpy.execute("ALTER TABLE intergeom1 ADD COLUMN seq bigint")
plpy.execute("CREATE INDEX intergeom1_GIST ON intergeom1 USING GIST (geom_clPt)")
plpy.info("intergeom table created with id")
plpy.execute("DROP TABLE IF EXISTS temp_dupes")
plpy.execute("CREATE TEMP TABLE temp_dupes AS (SELECT " + noded_vertices + ".*, intergeom1.id as iid FROM " + noded_vertices + ", intergeom1 WHERE " + noded_vertices + ".the_geom && geom_clPt)")
plpy.info("Temp dup points table created")
res = plpy.execute("DELETE FROM intergeom1 WHERE intergeom1.id IN (SELECT temp_dupes.iid FROM temp_dupes)")
plpy.info("Deleted " + str(res.status()) + " vertices")
plpy.execute("SELECT cut_ways_newout('intergeom1'::text, '" + noded_ways + "'::text)")
plpy.execute("ALTER TABLE " + noded_ways + " DROP COLUMN IF EXISTS meshid_rightway")
plpy.execute("ALTER TABLE " + noded_ways + " DROP COLUMN IF EXISTS meshid_wrongway")
plpy.execute("ALTER TABLE " + noded_ways + " ADD COLUMN meshid_rightway bigint")
plpy.execute("ALTER TABLE " + noded_ways + " ADD COLUMN meshid_wrongway bigint")

$$ LANGUAGE plpython3u;
