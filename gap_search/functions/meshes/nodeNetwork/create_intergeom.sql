/*PGR-GNU*****************************************************************
Copyright (c) 2015 pgRouting developers
Mail: project@pgrouting.org
Author: Nicolas Ribot, 2013
------
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
********************************************************************PGR-GNU*/

CREATE OR REPLACE FUNCTION create_intergeom(edge_table text, tolerance double precision,
			id text default 'id', the_geom text default 'the_geom', table_ending text default 'noded',
            rows_where text DEFAULT ''::text, outall boolean DEFAULT false) RETURNS text AS
$BODY$
DECLARE
	/*
	 * Author: Nicolas Ribot, 2013
	*/
	p_num int := 0;
	p_ret text := '';
    pgis_ver_old boolean := _pgr_versionless(postgis_lib_version(), '2.1.0.0');
    vst_line_substring text;
    vst_line_locate_point text;
    intab text;
    outtab text;
    n_pkey text;
    n_geom text;
    naming record;
    sname text;
    tname text;
    outname text;
    srid integer;
    sridinfo record;
    splits bigint;
    touched bigint;
    untouched bigint;
    geomtype text;
    debuglevel text;
    rows_where text;
    vertices_table text;
    noded_ways text;
    noded_vertices text;


BEGIN
  execute 'show client_min_messages' into debuglevel;

  BEGIN
    RAISE DEBUG 'Checking % exists',edge_table;
    execute 'select * from _pgr_getTableName('||quote_literal(edge_table)||',0)' into naming;
    sname=naming.sname;
    tname=naming.tname;
    IF sname IS NULL OR tname IS NULL THEN
	RAISE NOTICE '-------> % not found',edge_table;
        RETURN 'FAIL';
    ELSE
	RAISE DEBUG '  -----> OK';
    END IF;

    intab=sname||'.'||tname;
    outname=tname||'_'||table_ending;
    outtab= sname||'.'||outname;
    rows_where = CASE WHEN length(rows_where) > 2 and not outall THEN ' AND (' || rows_where || ')' ELSE '' END;
    rows_where = CASE WHEN length(rows_where) > 2 THEN ' WHERE (' || rows_where || ')' ELSE '' END;
  END;

  BEGIN
       raise DEBUG 'Checking id column "%" columns in  % ',id,intab;
       EXECUTE 'select _pgr_getColumnName('||quote_literal(intab)||','||quote_literal(id)||')' INTO n_pkey;
       IF n_pkey is NULL then
          raise notice  'ERROR: id column "%"  not found in %',id,intab;
          RETURN 'FAIL';
       END IF;
  END;


  BEGIN
       raise DEBUG 'Checking id column "%" columns in  % ',the_geom,intab;
       EXECUTE 'select _pgr_getColumnName('||quote_literal(intab)||','||quote_literal(the_geom)||')' INTO n_geom;
       IF n_geom is NULL then
          raise notice  'ERROR: the_geom  column "%"  not found in %',the_geom,intab;
          RETURN 'FAIL';
       END IF;
  END;

  IF n_pkey=n_geom THEN
	raise notice  'ERROR: id and the_geom columns have the same name "%" in %',n_pkey,intab;
        RETURN 'FAIL';
  END IF;

  BEGIN
       	raise DEBUG 'Checking the SRID of the geometry "%"', n_geom;
       	EXECUTE 'SELECT ST_SRID(' || quote_ident(n_geom) || ') as srid '
          		|| ' FROM ' || _pgr_quote_ident(intab)
          		|| ' WHERE ' || quote_ident(n_geom)
          		|| ' IS NOT NULL LIMIT 1' INTO sridinfo;
       	IF sridinfo IS NULL OR sridinfo.srid IS NULL THEN
        	RAISE NOTICE 'ERROR: Can not determine the srid of the geometry "%" in table %', n_geom,intab;
           	RETURN 'FAIL';
       	END IF;
       	srid := sridinfo.srid;
       	raise DEBUG '  -----> SRID found %',srid;
       	EXCEPTION WHEN OTHERS THEN
           		RAISE NOTICE 'ERROR: Can not determine the srid of the geometry "%" in table %', n_geom,intab;
           		RETURN 'FAIL';
  END;

    BEGIN
      RAISE DEBUG 'Checking "%" column in % is indexed',n_pkey,intab;
      if (_pgr_isColumnIndexed(intab,n_pkey)) then
	RAISE DEBUG '  ------>OK';
      else
        RAISE DEBUG ' ------> Adding  index "%_%_idx".',n_pkey,intab;

	set client_min_messages  to warning;
        execute 'create  index '||tname||'_'||n_pkey||'_idx on '||_pgr_quote_ident(intab)||' using btree('||quote_ident(n_pkey)||')';
	execute 'set client_min_messages  to '|| debuglevel;
      END IF;
    END;

    BEGIN
      RAISE DEBUG 'Checking "%" column in % is indexed',n_geom,intab;
      if (_pgr_iscolumnindexed(intab,n_geom)) then
	RAISE DEBUG '  ------>OK';
      else
        RAISE DEBUG ' ------> Adding unique index "%_%_gidx".',intab,n_geom;
	set client_min_messages  to warning;
        execute 'CREATE INDEX '
            || quote_ident(tname || '_' || n_geom || '_gidx' )
            || ' ON ' || _pgr_quote_ident(intab)
            || ' USING gist (' || quote_ident(n_geom) || ')';
	execute 'set client_min_messages  to '|| debuglevel;
      END IF;
    END;
---------------
    BEGIN
       raise DEBUG 'initializing %',outtab;
       execute 'select * from _pgr_getTableName('||quote_literal(outtab)||',0)' into naming;
       IF sname=naming.sname  AND outname=naming.tname  THEN
           execute 'TRUNCATE TABLE '||_pgr_quote_ident(outtab)||' RESTART IDENTITY';
           execute 'SELECT DROPGEOMETRYCOLUMN('||quote_literal(sname)||','||quote_literal(outname)||','||quote_literal(n_geom)||')';
       ELSE
	   set client_min_messages  to warning;
       	   execute 'CREATE TABLE '||_pgr_quote_ident(outtab)||' (id bigserial PRIMARY KEY,old_id integer,sub_id integer,
								source bigint,target bigint)';
       END IF;
       execute 'select geometrytype('||quote_ident(n_geom)||') from  '||_pgr_quote_ident(intab)||' limit 1' into geomtype;
       execute 'select addGeometryColumn('||quote_literal(sname)||','||quote_literal(outname)||','||
                quote_literal(n_geom)||','|| srid||', '||quote_literal(geomtype)||', 2)';
       execute 'CREATE INDEX '||quote_ident(outname||'_'||n_geom||'_idx')||' ON '||_pgr_quote_ident(outtab)||'  USING GIST ('||quote_ident(n_geom)||')';
	execute 'set client_min_messages  to '|| debuglevel;
       raise DEBUG  '  ------>OK';
    END;
----------------

	DROP TABLE IF EXISTS intergeom;

--    -- First creates temp table with intersection points
    p_ret = 'create table intergeom as (
        select l1.' || quote_ident(n_pkey) || ' as l1id,
               l2.' || quote_ident(n_pkey) || ' as l2id,
	       l1.' || quote_ident(n_geom) || ' as line1,
	       _pgr_startpoint(l2.' || quote_ident(n_geom) || ') as source,
	       _pgr_endpoint(l2.' || quote_ident(n_geom) || ') as target,
               st_intersection(l1.' || quote_ident(n_geom) || ', l2.' || quote_ident(n_geom) || ') as geom
        from (SELECT * FROM ' || _pgr_quote_ident(intab) || rows_where || ') as l1
             join (SELECT * FROM ' || _pgr_quote_ident(intab) || rows_where || ') as l2
             on (st_dwithin(l1.' || quote_ident(n_geom) || ', l2.' || quote_ident(n_geom) || ', ' || tolerance || '))'||
        'where l1.' || quote_ident(n_pkey) || ' <> l2.' || quote_ident(n_pkey)||' and
	st_equals(_pgr_startpoint(l1.' || quote_ident(n_geom) || '),_pgr_startpoint(l2.' || quote_ident(n_geom) || '))=false and
	st_equals(_pgr_startpoint(l1.' || quote_ident(n_geom) || '),_pgr_endpoint(l2.' || quote_ident(n_geom) || '))=false and
	st_equals(_pgr_endpoint(l1.' || quote_ident(n_geom) || '),_pgr_startpoint(l2.' || quote_ident(n_geom) || '))=false and
	st_equals(_pgr_endpoint(l1.' || quote_ident(n_geom) || '),_pgr_endpoint(l2.' || quote_ident(n_geom) || '))=false  )';
    raise debug '%',p_ret;
    EXECUTE p_ret;

    RETURN 'OK';
END;
$BODY$
    LANGUAGE 'plpgsql';


--COMMENT ON FUNCTION pgr_nodeNetworkp(text, double precision, text, text, text, text, boolean )
--IS 'edge_table, tolerance, id:=''id'', the_geom:=''the_geom'', table_ending:=''noded'' ';
