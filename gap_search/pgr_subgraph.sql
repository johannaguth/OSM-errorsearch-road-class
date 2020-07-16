--- Author: Johanna Stötzer
-- Creates regional tables for ways and vertices
-- Sample Call: SELECT pgr_subgraph(geom, '_tasmania'::text, 'ways'::text, 'ways_vertices_pgr'::text) FROM tasmania_bb;
-- Last Change: 30.1.19 - added 2nd function and changed name from pgr_region_graph to pgr_subgraph

CREATE OR REPLACE FUNCTION pgr_subgraph(
	region_geom geometry,
	region_ending text,
	general_ways text,
	general_vertices text
	) RETURNS void
AS $$ 

DECLARE
affected_rows int;
StartTime timestamptz;
EndTime timestamptz;
Delta float;
ways_table text;
vertices_table text;
ways_gist text;
vertices_gist text;
sequence_way text;
sequence_vertice text;


BEGIN
	StartTime := clock_timestamp();
	
	ways_table := 'ways' || region_ending;
	vertices_table := ways_table || '_vertices_pgr' ;
	ways_gist := ways_table || '_gist1' ;
	vertices_gist := vertices_table || '_gist1' ;
	sequence_way := 'sequence_way' || region_ending;
	sequence_vertice := 'sequence_vertice' || region_ending;

	EXECUTE FORMAT('DROP SEQUENCE IF EXISTS %1$I CASCADE', sequence_way);
	EXECUTE FORMAT('DROP TABLE IF EXISTS %1$I CASCADE', ways_table);
	EXECUTE FORMAT(
		'CREATE TABLE %1$I AS( '
		'SELECT DISTINCT %2$I.* '
		'FROM %2$I '
		'WHERE %2$I.the_geom && ST_transform($1,4326) '
		'AND ST_Intersects(%2$I.the_geom, ST_transform($1,4326))) '
	, ways_table, general_ways)
	USING region_geom;

	EXECUTE FORMAT('CREATE SEQUENCE %1$I', sequence_way);
	EXECUTE FORMAT('ALTER TABLE %1$I ALTER COLUMN gid SET DEFAULT nextval(''%2$I'') ', ways_table, sequence_way);
	EXECUTE FORMAT('ALTER TABLE %1$I ALTER COLUMN gid SET NOT NULL', ways_table);
	EXECUTE FORMAT('ALTER SEQUENCE %2$I OWNED BY %1$I.gid ', ways_table, sequence_way);   
	EXECUTE FORMAT('SELECT setval(''%2$I'', (SELECT MAX(gid)+1 FROM %1$I)) ', ways_table, sequence_way);

	EXECUTE FORMAT('ALTER TABLE %1$I ADD PRIMARY KEY (gid)', ways_table);
	EXECUTE FORMAT('CREATE INDEX %2$I ON %1$I USING GIST (the_geom)', ways_table, ways_gist);
	
	
	RAISE NOTICE 'ways region table created with index and primary key';
	
	EXECUTE FORMAT('DROP SEQUENCE IF EXISTS %1$I CASCADE', sequence_vertice);
	EXECUTE FORMAT('DROP TABLE IF EXISTS %1$I CASCADE', vertices_table);
	
	EXECUTE FORMAT(
		'CREATE TABLE %1$I AS( '
		'SELECT %3$I.* '
		'FROM %3$I '
		'WHERE %3$I.id IN (SELECT %2$I.source FROM %2$I UNION SELECT %2$I.target FROM %2$I))'
	, vertices_table, ways_table, general_vertices);

	EXECUTE FORMAT('CREATE SEQUENCE %1$I', sequence_vertice);
	EXECUTE FORMAT('ALTER TABLE %1$I ALTER COLUMN id SET DEFAULT nextval(''%2$I'') ', vertices_table, sequence_vertice);
	EXECUTE FORMAT('ALTER TABLE %1$I ALTER COLUMN id SET NOT NULL ', vertices_table);
	EXECUTE FORMAT('ALTER SEQUENCE %2$I OWNED BY %1$I.id ', vertices_table, sequence_vertice);   
	EXECUTE FORMAT('SELECT setval(''%2$I'', (SELECT MAX(id)+1 FROM %1$I)) ', vertices_table, sequence_vertice); 

	EXECUTE FORMAT('ALTER TABLE %1$I ADD PRIMARY KEY (id)', vertices_table);
	EXECUTE FORMAT('CREATE INDEX %2$I ON %1$I USING GIST (the_geom)', vertices_table, vertices_gist);
	
	RAISE NOTICE 'ways region table created with index and primary key';
	
	EndTime := clock_timestamp();
  	Delta := ( extract(epoch from EndTime) - extract(epoch from StartTime) );
	RAISE NOTICE 'Duration of pgr_region_graph in millisecs=%1, seconds =%2, minutes=%3', Delta * 1000, Delta, Delta/60 ;	
END;
$$ LANGUAGE 'plpgsql';

--- Author: Johanna Stötzer
-- Creates subgraph tables for ways and vertices
-- Sample Call: SELECT pgr_subgraph(1, '_tasmania'::text, 'ways'::text, 'ways_vertices_pgr'::text);



CREATE OR REPLACE FUNCTION pgr_subgraph(
	graph_level int,
	region_ending text,
	general_ways text,
	general_vertices text
	) RETURNS void
AS $$ 

DECLARE
affected_rows int;
StartTime timestamptz;
EndTime timestamptz;
Delta float;
ways_table text;
vertices_table text;
ways_gist text;
vertices_gist text;
sequence_way text;
sequence_vertice text;


BEGIN
	StartTime := clock_timestamp();
	
	ways_table := 'ways' || region_ending || '_l' || graph_level::text;
	vertices_table := ways_table || '_vertices_pgr' ;
	ways_gist := ways_table || '_gist1' ;
	vertices_gist := vertices_table || '_gist1' ;
	sequence_way := 'sequence_way' || region_ending || '_l' || graph_level::text;
	sequence_vertice := 'sequence_vertice' || region_ending || '_l' || graph_level::text;

	EXECUTE FORMAT('DROP SEQUENCE IF EXISTS %1$I CASCADE', sequence_way);
	EXECUTE FORMAT('DROP TABLE IF EXISTS %1$I CASCADE', ways_table);
	EXECUTE FORMAT(
		'CREATE TABLE %1$I AS( '
		'SELECT DISTINCT %2$I.* '
		'FROM %2$I '
		'WHERE level <= $1)'
	, ways_table, general_ways)
	
	USING graph_level;

	EXECUTE FORMAT('CREATE SEQUENCE %1$I', sequence_way);
	EXECUTE FORMAT('ALTER TABLE %1$I ALTER COLUMN gid SET DEFAULT nextval(''%2$I'') ', ways_table, sequence_way);
	EXECUTE FORMAT('ALTER TABLE %1$I ALTER COLUMN gid SET NOT NULL', ways_table);
	EXECUTE FORMAT('ALTER SEQUENCE %2$I OWNED BY %1$I.gid ', ways_table, sequence_way);   
	EXECUTE FORMAT('SELECT setval(''%2$I'', (SELECT MAX(gid)+1 FROM %1$I)) ', ways_table, sequence_way);

	EXECUTE FORMAT('ALTER TABLE %1$I ADD PRIMARY KEY (gid)', ways_table);
	EXECUTE FORMAT('CREATE INDEX %2$I ON %1$I USING GIST (the_geom)', ways_table, ways_gist);
	
	
	RAISE NOTICE 'ways region table created with index and primary key';
	
	EXECUTE FORMAT('DROP SEQUENCE IF EXISTS %1$I CASCADE', sequence_vertice);
	EXECUTE FORMAT('DROP TABLE IF EXISTS %1$I CASCADE', vertices_table);
	
	EXECUTE FORMAT(
		'CREATE TABLE %1$I AS( '
		'SELECT %3$I.* '
		'FROM %3$I '
		'WHERE %3$I.id IN (SELECT %2$I.source FROM %2$I UNION SELECT %2$I.target FROM %2$I))'
	, vertices_table, ways_table, general_vertices);

	EXECUTE FORMAT('CREATE SEQUENCE %1$I', sequence_vertice);
	EXECUTE FORMAT('ALTER TABLE %1$I ALTER COLUMN id SET DEFAULT nextval(''%2$I'') ', vertices_table, sequence_vertice);
	EXECUTE FORMAT('ALTER TABLE %1$I ALTER COLUMN id SET NOT NULL ', vertices_table);
	EXECUTE FORMAT('ALTER SEQUENCE %2$I OWNED BY %1$I.id ', vertices_table, sequence_vertice);   
	EXECUTE FORMAT('SELECT setval(''%2$I'', (SELECT MAX(id)+1 FROM %1$I)) ', vertices_table, sequence_vertice); 

	EXECUTE FORMAT('ALTER TABLE %1$I ADD PRIMARY KEY (id)', vertices_table);
	EXECUTE FORMAT('CREATE INDEX %2$I ON %1$I USING GIST (the_geom)', vertices_table, vertices_gist);
	
	RAISE NOTICE 'ways region table created with index and primary key';
	
	EndTime := clock_timestamp();
  	Delta := ( extract(epoch from EndTime) - extract(epoch from StartTime) );
	RAISE NOTICE 'Duration of pgr_subgraph in millisecs=%1, seconds =%2, minutes=%3', Delta * 1000, Delta, Delta/60 ;	
END;
$$ LANGUAGE 'plpgsql';
