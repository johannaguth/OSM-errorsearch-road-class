--- Author: Johanna Guth
-- First function give_pointsquantile(): Gives points to the value where x percent of oll values are below, x being the input percentile
-- Second function give_pointsvalues(): Gives according points to all values that are below the input values
-- Sample Call 1: SELECT give_pointsquantile('od_tab_nsw_l3_test'::text, ARRAY[0.25,0.44,0.58,0.685,0.76,0.82,0.865,0.9,0.925,0.95], 'agg_min_eucl'::text, 'points_1'::text);
-- Sample Call w: SELECT give_pointsvalues('od_candidates_l3'::text, ARRAY[1.1,1.5,2,3,5,10,20,40,60,100], 'lev_div_alllev_pathdist'::text, 'points_4'::text);


CREATE OR REPLACE FUNCTION give_pointsquantile(
	tab_name text,
	perc_array float[],
	col_name text,
	points_col text,
	filter text default ' ',
	reverse boolean default FALSE
) RETURNS void
AS $$
	if reverse:
		# Defining percentage borders for points (upper limit)
		p0 = perc_array[9]
		p1 = perc_array[8]
		p2 = perc_array[7]
		p3 = perc_array[6]
		p4 = perc_array[5]
		p5 = perc_array[4]
		p6 = perc_array[3]
		p7 = perc_array[2]
		p8 = perc_array[1]
		p9 = perc_array[0]

		# Updating the points column
		plpy.execute("WITH percentiles AS (SELECT k, percentile_disc(k) WITHIN GROUP (ORDER BY " + col_name + ") " +
		"FROM " + tab_name + " , generate_series(0.001, 1, 0.001) AS k "+ filter +" GROUP BY k)"
			"UPDATE " + tab_name + " SET " + points_col + " = CASE " +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p0) + ") THEN 0" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p1) + ") THEN 1" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p2) + ") THEN 2" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p3) + ") THEN 3" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p4) + ") THEN 4" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p5) + ") THEN 5" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p6) + ") THEN 6" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p7) + ") THEN 7" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p8) + ") THEN 8" +
			" WHEN " + col_name + " >= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p9) + ") THEN 9" +
			" ELSE 10 END "+ filter)

	else:
		# Defining percentage borders for points (upper limit)
		p0 = perc_array[0]
		p1 = perc_array[1]
		p2 = perc_array[2]
		p3 = perc_array[3]
		p4 = perc_array[4]
		p5 = perc_array[5]
		p6 = perc_array[6]
		p7 = perc_array[7]
		p8 = perc_array[8]
		p9 = perc_array[9]

		# Updating the points column
		plpy.execute("WITH percentiles AS (SELECT k, percentile_disc(k) WITHIN GROUP (ORDER BY " + col_name + ") " +
		"FROM " + tab_name + " , generate_series(0.001, 1, 0.001) AS k "+ filter +" GROUP BY k)"
			"UPDATE " + tab_name + " SET " + points_col + " = CASE " +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p0) + ") THEN 0" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p1) + ") THEN 1" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p2) + ") THEN 2" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p3) + ") THEN 3" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p4) + ") THEN 4" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p5) + ") THEN 5" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p6) + ") THEN 6" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p7) + ") THEN 7" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p8) + ") THEN 8" +
			" WHEN " + col_name + " <= (SELECT percentile_disc FROM percentiles WHERE k = " + str(p9) + ") THEN 9" +
			" ELSE 10 END "+ filter)

$$ LANGUAGE plpython3u;


-- SELECT k, percentile_disc(k) WITHIN GROUP (ORDER BY agg_div_eucl) FROM od_cand_l3 , generate_series(0.05, 1, 0.05) AS k GROUP BY k


CREATE OR REPLACE FUNCTION give_pointsvalues(
	tab_name text,
	perc_array float[],
	col_name text,
	points_col text
) RETURNS void
AS $$
	# Defining percentage borders for points (upper limit)
	p0 = perc_array[0]
	p1 = perc_array[1]
	p2 = perc_array[2]
	p3 = perc_array[3]
	p4 = perc_array[4]
	p5 = perc_array[5]
	p6 = perc_array[6]
	p7 = perc_array[7]
	p8 = perc_array[8]
	p9 = perc_array[9]

	# Updating the points column
	plpy.execute(
		"UPDATE " + tab_name + " SET " + points_col + " = CASE " +
		" WHEN " + col_name + " <= " + str(p0) + " THEN 0" +
		" WHEN " + col_name + " <= " + str(p1) + " THEN 1" +
		" WHEN " + col_name + " <= " + str(p2) + " THEN 2" +
		" WHEN " + col_name + " <= " + str(p3) + " THEN 3" +
		" WHEN " + col_name + " <= " + str(p4) + " THEN 4" +
		" WHEN " + col_name + " <= " + str(p5) + " THEN 5" +
		" WHEN " + col_name + " <= " + str(p6) + " THEN 6" +
		" WHEN " + col_name + " <= " + str(p7) + " THEN 7" +
		" WHEN " + col_name + " <= " + str(p8) + " THEN 8" +
		" WHEN " + col_name + " <= " + str(p9) + " THEN 9" +
		" ELSE 10 END ")

$$ LANGUAGE plpython3u;
