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

Load now the production database into your local `app-digitaal-loket` repo and wait for migrations to run. Once done, comment out `command: "tail -f /dev/null"`, and data export can commence.

Exporting the data will occur through [sparql-export-script](https://github.com/Riadabd/sparql-export-script). The necessary `CONSTRUCT` queries should be placed inside the `queries/` directory; these queries have already been written and are ready to be used. The default endpoint for the export service is `http://localhost:8890`, so there is no need to specify one (provided you have the loket repo running and are using the default SPARQL endpoint).

If `--write-temp-graphs <graph-name>` is passed as an argument for the script, it will automatically generate a graph file alongside the turtle file with the following naming scheme:

* Script name: `construct-ConceptDisplayConfiguration.sparql`
* If "graph-name" was passed as `http://mu.semte.ch/graphs/temp`, the resulting graph file will contain `http://mu.semte.ch/graphs/temp/ConceptDisplayConfiguration` as the temporary graph.

## Import LPDC production data

After exporting is finished, the resulting exports for each type are placed in individual folders and stored inside the local `tmp/` folder; these folders can then be copied to `import-lpdc-production-data/` (or any other folder name) inside `config/migrations/local/2023/` in `app-lpdc-digitaal-loket-prod` to allow the migrations to run.

Before running migrations in `app-lpdc-digitaal-loket`, make sure to edit the parameters described in the [Note on Virtuoso settings](#note-on-virtuoso-settings) section.

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

When trying out the export/import process locally, I was getting a total of 421 concepts instead of the expected 420 since the extra deleted snapshot was showing up in the list; the goal is to find a way to hide this archived concept from the user. A ticket has been made to address this issue: [https://binnenland.atlassian.net/browse/LPDC-589](https://binnenland.atlassian.net/browse/LPDC-589).

Once everything is set up, we can delete all data inside the temporary graphs:

```
DELETE WHERE {
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

Restore the values inside `config/virtuoso/virtuoso-production.ini` back to their original values (back to 1 million from 10 million).