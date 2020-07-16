# OSM-errorsearch-road-class
A pgSQL software package that finds road classification errors in OpenStreetMap. It contains all functions required for the error search and an exemplary application for the state of New South Wales in Australia. Furthermore, an error reference dataset is provided with road class errors in New South Wales.

The developed error search consists of two independent parts: (a) the search for disconnected network components and (b) the gap search.
These parts can run indepentent of each other.

## Requirements
Software: 
  - pgSQL database -> minimal version: V 11 (Requires procedures)
  - PostGIS & pgrouting extensions

Data:
  - The countries road network table created with osm2pgrouting
  - Some kind of region geometry polygon if a subregion is analyzed

## Publication

The theory behind the error search, the application of this software, and its development are described in the paper "..." (LINK) which is currently under review at the Journal of Spatial Information Science. Please read the paper before applying the software.

## Application

To apply the error search for a different region the following steps must be performed:

(A) Search for disconnected network components
  1. Create all functions in the folder "discComp_search/functions"
  2. Run "discComp_alllevels.sql" -> to change: if necessary ways table
  3. Result = Geometry collections of all subgraphs
  
(B) Gap search
  1. Create all functions in the folder "gap_search/functions"
  2. Prepare the different levels of the road network by running "preparation_errors.sql" with your region (to change: region ending, region geometry, if necessary ways and ways_vertices_pgr table)
  3. Run all scripts in "gap_search/levelled_search -> Some parameters might have to be adapted:
  
    - Quantiles of filter 2 (75% G1 and 25% of G2)
    - Rating system for G3
  4. Result = Table with O-D Pairs "od_cand_lx" per road network level  -> Columns with the calculated parameters and with the rating system
