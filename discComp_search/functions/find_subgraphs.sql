--- Author: Johanna Guth
-- Finds all subgraphs on one level and gives them a graph id
-- Sample Call: SELECT find_subgraphs('ways_nsw_l3_noded'::text);
-- Last Change:  9.3. added descriptions


CREATE OR REPLACE FUNCTION find_subgraphs(
	ways_table text
	) RETURNS void
AS $$

	import time
	tic = time.time()
	vertices_table = ways_table + "_vertices_pgr"

## Adds a new column "graph_id" to vertices_table
	plpy.execute("ALTER TABLE " + vertices_table + " DROP COLUMN IF EXISTS graph_id")
	plpy.execute("ALTER TABLE " + vertices_table + " ADD COLUMN graph_id integer")

## Select all ids from vertices table and create list "node_ids_list" from it
	node_ids = plpy.execute("SELECT id FROM " + vertices_table)
	node_ids_list= []
	for i in node_ids:
		node_ids_list.append(int(i['id']))

## Initialize current graph with first item in the list of vertice ids
	current_graph = [node_ids_list[0]]
	working_on = [node_ids_list[0]]
	continue_l = True
	subgraph = 0
## SET graph_id of first item in the list of vertice ids = 0
	plpy.execute("UPDATE " + vertices_table + " SET graph_id = " + str(subgraph) + " WHERE id = " + str(working_on[0]))

	while continue_l == True:
	## If there is an item in node_ids_list or in working_on
		if node_ids_list or working_on:
			## If working_on (one subgraph is done) is empty --> select next id in node_ids_list (next subgraph)
			if not working_on:
				working_on.append(node_ids_list[0])
				current_graph = [working_on[0]]
				plpy.info("Subgraph found: " + str(subgraph))
				subgraph += 1
				plpy.execute("UPDATE " + vertices_table + " SET graph_id = " + str(subgraph) + " WHERE id = " + str(working_on[0]))
			## Node to evaluate is the first in the list currentnode
			currentnode = working_on[0]
			## Query all vertices that are connected to the current node
			connected_vertices = plpy.execute("SELECT id FROM " + vertices_table + ", " + ways_table + " WHERE (target = " + str(currentnode) + " OR source = " + str(currentnode) + ") AND (id = target OR id = source) AND id != " + str(currentnode))
			## set graph id of all connected vertice to the current graph id
			for i in connected_vertices:
				# if the id is not in the already visited nodes append it to current_graph an to working_on
				if not int(i['id']) in current_graph:
					plpy.execute("UPDATE " + vertices_table + " SET graph_id = " + str(subgraph) + " WHERE id = " + str(i['id']))
					current_graph.append(int(i['id']))
					working_on.append(int(i['id']))
			# remove the current node from the lists
			node_ids_list.remove(currentnode)
			working_on.remove(currentnode)
		## If there is no item in both node_ids_list and in working_on: end loop
		else:
			continue_l = False

	toc = time.time()
	plpy.info('Function find_subgraphs took ' + str(toc - tic) + ' seconds.')

$$ LANGUAGE plpython3u;
