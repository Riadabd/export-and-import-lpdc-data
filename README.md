# Transfer LPDC production data from `app-digitaal-loket` to `app-lpdc-digitaal-loket`

## Note on Virtuoso settings

The following parameters must be changed inside `config/virtuoso/virtuoso-production.ini` before any data export/import was performed due to some types containing a large number of triples.

```
MaxVectorSize     = 10000000 ; Query vector size threshold, edited from 1 million to 10 million
MaxSortedTopRows  = 10000000 ; Edited from 1 million to 10 million
ResultSetMaxRows  = 10000000 ; Edited from 1 million to 10 million
```

## Export LPDC production data

First, download the production database onto your local system since some database parameters have to be tweaked before data can be correctly exported. The [Note on Virtuoso settings](#note-on-virtuoso-settings) section describes what file and which parameters need to be changed.

Add the following to your `docker-compose.override.yml` in `app-digitaal-loket` in order to load the production database:

```
virtuoso:
    volumes:
      - ./data/db:/data
      - ./config/virtuoso/virtuoso-production.ini:/data/virtuoso.ini
      - ./config/virtuoso/:/opt/virtuoso-scripts
    command: "tail -f /dev/null"
```

Load the production database into your local `app-digitaal-loket` repo and wait for migrations to run. Once done, comment out `command: "tail -f /dev/null"`. Data export can now commence.

Exporting the data will occur through [sparql-export-script](https://github.com/Riadabd/sparql-export-script). The necessary `CONSTRUCT` queries should be placed inside the `construct_queries/` directory; these queries have already been written and are ready to be used. The default endpoint for the export service is `http://localhost:8890`, so there is no need to specify one (provided you have the loket repo running and are using the default SPARQL endpoint).

If `--write-temp-graphs <graph-name>` is passed as an argument for the script, it will automatically generate a graph file alongside the turtle file with the following naming scheme:

* Script name: `construct-ConceptDisplayConfiguration.sparql`
* If "graph-name" was passed as `http://mu.semte.ch/graphs/temp`, the resulting graph file will contain `http://mu.semte.ch/graphs/temp/ConceptDisplayConfiguration` as the temporary graph.

## Import LPDC production data

After exporting is finished, the resulting exports for each type are placed in individual folders and stored inside the local `tmp/` folder; these folders can then be copied to `import-lpdc-production-data/` (or any other folder name) inside `config/migrations/local/2023/` in `app-lpdc-digitaal-loket-prod` to allow the migrations to run.

Before running migrations in `app-lpdc-digitaal-loket`, make sure to edit the parameters described in the [Note on Virtuoso settings](#note-on-virtuoso-settings) section. After editing the parameters, add the following to your `docker-compose.override.yml` file:

```
virtuoso:
    volumes:
      - ./data/db:/data
      - ./config/virtuoso/virtuoso-production.ini:/data/virtuoso.ini
      - ./config/virtuoso/:/opt/virtuoso-scripts
```

Shut down the running stack in `app-digitaal-loket` (`drc down`) and start the migrations for `app-lpdc-digitaal-loket` (`drc up -d migrations`).

Once the migrations have run, the following `INSERT` queries can be performed to place triples back to their original graphs:

```
PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>

INSERT {
  GRAPH ?g {
   ?s ?p ?o .
  }
}
WHERE {
  VALUES ?h {
    <http://mu.semte.ch/graphs/temp/ConceptualPublicService>
    <http://mu.semte.ch/graphs/temp/PublicService>
    <http://mu.semte.ch/graphs/temp/Tombstone>
    <http://mu.semte.ch/graphs/temp/PublicOrganisation>
    <http://mu.semte.ch/graphs/temp/Requirement>
    <http://mu.semte.ch/graphs/temp/Evidence>
    <http://mu.semte.ch/graphs/temp/Rule>
    <http://mu.semte.ch/graphs/temp/Cost>
    <http://mu.semte.ch/graphs/temp/Output>
    <http://mu.semte.ch/graphs/temp/FinancialAdvantage>
    <http://mu.semte.ch/graphs/temp/LegalResource>
    <http://mu.semte.ch/graphs/temp/ContactPoint>
    <http://mu.semte.ch/graphs/temp/Location>
    <http://mu.semte.ch/graphs/temp/Website>
    <http://mu.semte.ch/graphs/temp/Address>
  }

  GRAPH ?h {
    ?s a ?type ;
      ?p ?o ;
      ext:wasInGraph ?g .
  }
}
```

The above query moves all types except `ConceptDisplayConfiguration`, which is handled by the query below.

```
PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>

INSERT {
  GRAPH ?g {
   ?s ?p ?o .
   ?target ?targetP ?s .
  }
}
WHERE {
  VALUES ?h {
    <http://mu.semte.ch/graphs/temp/ConceptDisplayConfiguration>
  }

  GRAPH ?h {
    ?s a ?type ;
      ?p ?o ;
      ext:wasInGraph ?g .
    
    ?target ?targetP ?s .
  }
}
```

At this stage, all triples have been moved, and are situated in their correct graphs. One thing to check is whether there are any concept snapshots marked as `Delete`; these can be found throught the following query:

```
PREFIX lpdcExt: <https://productencatalogus.data.vlaanderen.be/ns/ipdc-lpdc#>
PREFIX dct:     <http://purl.org/dc/terms/>
PREFIX mu:      <http://mu.semte.ch/vocabularies/core/>

SELECT * WHERE {
  GRAPH <http://mu.semte.ch/graphs/lpdc/ldes-data> {
    ?snapshot a lpdcExt:ConceptualPublicService ;
      dct:isVersionOf ?concept ;
      lpdcExt:snapshotType ?snapshotType .
    
    FILTER(?snapshotType = <https://productencatalogus.data.vlaanderen.be/id/concept/SnapshotType/Delete>)
  }

  GRAPH <http://mu.semte.ch/graphs/public> {
    ?concept a lpdcExt:ConceptualPublicService ;
      mu:uuid ?id .
  }
}
```

Once you get the number of archived concepts, make sure to check that the total number of concepts in the concept list aligns with that of Loket.

Once everything is set up, we can delete all data inside the temporary graphs:

```
DELETE {
  GRAPH ?g {
    ?s ?p ?o .
  }
}
WHERE {
  VALUES ?g {
    <http://mu.semte.ch/graphs/temp/ConceptualPublicService>
    <http://mu.semte.ch/graphs/temp/PublicService>
    <http://mu.semte.ch/graphs/temp/Tombstone>
    <http://mu.semte.ch/graphs/temp/PublicOrganisation>
    <http://mu.semte.ch/graphs/temp/Requirement>
    <http://mu.semte.ch/graphs/temp/Evidence>
    <http://mu.semte.ch/graphs/temp/Rule>
    <http://mu.semte.ch/graphs/temp/Cost>
    <http://mu.semte.ch/graphs/temp/Output>
    <http://mu.semte.ch/graphs/temp/FinancialAdvantage>
    <http://mu.semte.ch/graphs/temp/LegalResource>
    <http://mu.semte.ch/graphs/temp/ContactPoint>
    <http://mu.semte.ch/graphs/temp/Location>
    <http://mu.semte.ch/graphs/temp/Website>
    <http://mu.semte.ch/graphs/temp/Address>
    <http://mu.semte.ch/graphs/temp/ConceptDisplayConfiguration>
  }
  
  GRAPH ?g {
    ?s ?p ?o .
  }
}
```

In addition, delete all instances of `ext:wasInGraph`, which is the predicate used to map the types back to their correct graphs:

```
PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>

DELETE {
  GRAPH ?g {
    ?s ext:wasInGraph ?graph .
  }
}
WHERE {
  GRAPH ?g {
    ?s ext:wasInGraph ?graph .
  }
}
```

Restore the values inside `config/virtuoso/virtuoso-production.ini` back to their original values (back to 1 million from 10 million).

## Sanity Checks

Once the import is finished, we need to perform some sanity checks to make sure the number of triples for each LPDC type matches between Loket and the new LPDC production environment.

In order to streamline these checks, a script (`sanity_checks.sh`) has been made to automatically execute the `COUNT` queries inside `sanity_queries/` on two endpoints (one for Loket and another for LPDC). The results are sent to `results/sanity_type_count_results.csv`, which contains the type being counted, the count of this type in Loket, its count in the new LPDC app, and whether they are equal (`type,loket_count,lpdc_count,equal`).

The type count checks are done on a global level, so we cannot see how they are divided, but they do give us confidence if the numbers match up. To further push that confidence level, we also perform a sanity check to count the number of instantiated public services per bestuurseenheid, for both Loket and LPDC. In order to perform this check, execute `select_queries.sh` first in order to download a list of non-eredienst bestuurseenheden (located in `tmp_select_out/non_eredienst_bestuurseenheden.csv`). After performing the regular type count checks, `sanity_checks.sh` confirms the existence of the aforementioned csv file and runs queries to count the number of public services for distinct bestuurseenheden. The result of this is piped into `results/sanity_public_services_count_per_bestuurseenheid_results.csv`, in a similar fashion to `results/sanity_type_count_results.csv`.

The default endpoints are `http://localhost:8890` for LPDC, and `http:localhost:8892` for Loket. These can be changed by passing the `--lpdc-sparql-endpoint` and `--loket-sparql-endpoint` flags respectively.

### In case of mismatch

At the moment, only the `Requirement` type is displaying mismatches after the import process. The reason is due to the `<http://mu.semte.ch/vocabularies/core/uuid>` predicate being copied to the `ldes-data` graph; it should only be present in the `public graph`. The query below deletes the excessive triples:

```
PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>

DELETE {
  GRAPH <http://mu.semte.ch/graphs/lpdc/ldes-data> {
    ?s <http://mu.semte.ch/vocabularies/core/uuid> ?o .
  }
}
WHERE {
  VALUES ?type {
    <http://data.europa.eu/m8g/Requirement>
  }

  GRAPH <http://mu.semte.ch/graphs/lpdc/ldes-data> {
    ?s a ?type ;
      <http://mu.semte.ch/vocabularies/core/uuid> ?o .
  }
}
```

## Delete Data in Case of Success/Re-run

The process described above, as it stands, should work without issues; however, it is possible something goes wrong during the export/import process. We have to consider the possibility of both cases:

### Success

In this case, we want to delete all LPDC data from the dev, QA and production Loket environments. The `DELETE` queries inside `delete_queries/` will be executed by `delete_queries.sh`; the SPARQL endpoint is provided through `--sparql-endpoint` and is set to `http://localhost:8890` by default.

### Failure

Similar to the success state, LPDC data needs to be deleted from the LPDC prod instance in case of import or sanity check failure. The same `DELETE` queries inside `delete_queries\` need to be run through `delete_queries.sh`, and the SPARQL endpoint needs to be specified.