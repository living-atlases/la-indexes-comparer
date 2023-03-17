# la-indexes-comparer

`la-indexes-comparer` is a tool to compare Solr indexes/collections from Living Atlases portals. It support core and collections from `solr` and `solrcloud`, and `pipelines` and `biocache-store` indexes.

This is useful to compare different created indexes and see differences to take actions, (like to switch to use a new index).

## Usage

``` bash
dart run bin/la_indexes_comparer.dart -a https://your-solr-index-a -b https://your-solr-index-b -1 core-or-collection-a -2 core-or-collection-b -c https://collectory.l-a.site -l "cl2,cl3,cl6"
```

More options:
```
Usage:
-a, --solr-url-a (mandatory)        Solr URL A
-b, --solr-url-b (mandatory)        Solr URL B
-1, --collection-a (mandatory)      Collection A
-2, --collection-b (mandatory)      Collection B
-c, --collectory-url (mandatory)    Collectory URL
-l, --layers (mandatory)
    --[no-]drs                      Compare drs
                                    (defaults to on)
    --[no-]species                  Compare species
                                    (defaults to on)
    --[no-]truncate-species         Only show the start and end of the comparison of species
                                    (defaults to on)
    --[no-]inst                     Compare institutions
                                    (defaults to on)
    --[no-]compare-layers           Compare layers
                                    (defaults to on)
    --[no-]hubs                     Compare hubs
                                    (defaults to on)
    --[no-]csv-format               Print results in CSV format
-d, --[no-]debug                    Show some extra debug info
```

Its works also with basic auth:
``` 
dart run bin/la_indexes_comparer.dart -a https://user:pass@your-solr-index-a -b https://user:pass@your-solr-index-b -1 core-or-collection-a -2 core-or-collection-b -c https://collectory.l-a.site -l "cl2,cl3,cl6" 
```

## Output

It can generate markdown tables (useful for attaching in issues) or CSV tables. See this [sample output](results-sample.md).

## Install

Just download a [release binary](https://github.com/living-atlases/la-indexes-comparer/releases) and run it from your computer or a internal server.

## Development

To use this utility you will need [dart](https://dart.dev/get-dart), follow these steps:
- Clone this repository:
```bash
git clone https://github.com/living-atlases/la-indexes-comparer.git
```
- Navigate to the cloned repository:
```
cd la-indexex-comparer
```
- Install the dependencies:
```
dart pub get
```
- Modify and execute this utility from the command line:
```
dart run bin/la_indexes_comparer.dart (...)
```

## Compile

```
dart compile exe bin/la_indexes_comparer.dart
cp bin/la_indexes_comparer.exe bin/la_indexes_comparer # only to avoid the .exe
```

## Future steps

If useful, we can integrate this in the [la-toolkit](https://github.com/living-atlases/la-toolkit) as an additional tool or to detect issues. 

## License

MPL © [Living Atlases](https://living-atlases.gbif.org)
