# OSM Error Search for Road Classification Errors
A pgSQL software package that finds road classification errors in OpenStreetMap. It contains all functions required for the error search and an exemplary application for the state of New South Wales (NSW) in Australia. Furthermore, an error reference dataset is provided with road class errors in New South Wales.

The theory behind the error search, the application of this software, its development and a detailed evaluation of the results are described in the paper: 

Johanna Guth, Sina Keller, Stefan Hinz, and Stephan Winter. “Towards detecting, characterizing, and rating of road classiﬁcation errors in crowd-sourced road network databases”. In: Journal of Spatial Information Science 22 (2020), pp. 1–30. (http://josis.org/index.php/josis/article/viewFile/677/290)

I suggest reading the paper before applying the software.

The developed error search consists of two independent parts: (a) the search for disconnected network components and (b) the gap search.
These parts can run indepentent of each other.

## Requirements
Software: 
  - pgSQL database -> minimal version: V 11 (Requires procedures)
  - plPython
  - PostGIS & pgrouting extensions

Data:
  - The countries road network table created with osm2pgrouting
  - Some kind of region geometry polygon if a subregion is analyzed

## Application and project organization

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
      - Region ending for tables
      - Input tables (ways + ways_vertices_pgr)
  4. Result = Table with O-D Pairs "od_cand_lx" per road network level  -> Columns with the calculated parameters and with the rating system
  
  ## Reference Data
  Reference data for NSW in the form of an error reference dataset is presented in "refdata/errors_nsw.csv".
  
  ## Liscense
  This project is licensed under the BSD 3-Clause License - see the LISCENSE file for details.
  
  ## Authors
  Johanna Guth
