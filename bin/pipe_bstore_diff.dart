import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:intl/intl.dart' as intl;

Future<void> main(List<String> arguments) async {
  exitCode = 0; // presume success

  const bool defaultNoDrs = false;
  const bool defaultNoSpecies = false;
  const bool defaultTruncateSpecies = false;
  const bool defaultNoInst = false;
  const bool defaultNoLayers = false;
  const bool defaultNoHubs = false;
  const bool defaultCsvFormat = false;

  final parser = ArgParser()
    ..addOption('solr-url-a', abbr: 'a', help: 'Solr URL A', mandatory: true)
    ..addOption('solr-url-b', abbr: 'b', help: 'Solr URL B', mandatory: true)
    ..addOption('collection-a',
        abbr: '1', help: 'Collection A', mandatory: true)
    ..addOption('collection-b',
        abbr: '2', help: 'Collection B', mandatory: true)
    ..addOption('collectory-url',
        abbr: 'c', help: 'Collectory URL', mandatory: true)
    ..addFlag('no-drs', help: 'Don\'t compare drs', defaultsTo: defaultNoDrs)
    ..addFlag('no-species',
        help: 'Don\'t compare species', defaultsTo: defaultNoSpecies)
    ..addFlag('truncate-species',
        help: 'Only show the start and end of the comparison of species',
        defaultsTo: defaultTruncateSpecies)
    ..addFlag('no-inst',
        help: 'Don\'t compare institutions', defaultsTo: defaultNoInst)
    ..addFlag('no-layers',
        help: 'Don\'t compare hubs', defaultsTo: defaultNoLayers)
    ..addFlag('no-hubs', help: 'Don\'t compare hubs', defaultsTo: defaultNoHubs)
    ..addFlag('csv-format',
        help: 'Print results in CSV format', defaultsTo: defaultCsvFormat);

  try {
    final args = parser.parse(arguments);

    final String solrA = args['solr-url-a'] as String;
    final String solrB = args['solr-url-b'] as String;
    final String collectionA = args['collection-a'] as String;
    final String collectionB = args['collection-b'] as String;
    final collectoryUrl = args['collectory-url'];
    final compareDrs = !(args['no-drs'] as bool? ?? defaultNoDrs);
    final compareSpecies = !(args['no-species'] as bool? ?? defaultNoSpecies);
    final truncateSpecies =
        !(args['truncate-species'] as bool? ?? defaultTruncateSpecies);
    final compareInst = !(args['no-inst'] as bool? ?? defaultNoInst);
    final compareLayers = !(args['no-layers'] as bool? ?? defaultNoLayers);
    final compareHubs = !(args['no-hubs'] as bool? ?? defaultNoHubs);
    final csvFormat = args['csv-format'] as bool? ?? defaultCsvFormat;

    final SolrComparator comp = SolrComparator(
        solrA: solrA,
        solrB: solrB,
        collectionA: collectionA,
        collectionB: collectionB,
        collectoryUrl: collectoryUrl,
        compareDrs: compareDrs,
        compareSpecies: compareSpecies,
        compareInst: compareInst,
        compareLayers: compareLayers,
        compareHubs: compareHubs,
        truncateSpecies: truncateSpecies,
        csvFormat: csvFormat);
    comp.run();
  } catch (e) {
    print('Usage: ');
    print(parser.usage);
  }
}

class SolrComparator {
  SolrComparator(
      {required this.solrA,
      required this.solrB,
      required this.collectionA,
      required this.collectionB,
      required this.collectoryUrl,
      required this.compareDrs,
      required this.compareSpecies,
      required this.truncateSpecies,
      required this.compareInst,
      required this.compareLayers,
      required this.compareHubs,
      required this.csvFormat}) {
    solrS.add(solrA);
    solrS.add(solrB);
    collectionS.add(collectionA);
    collectionS.add(collectionB);
    titleS.addAll(['solrA $collectionA', "sorlB $collectionB"]);
    Result.csvFormat = csvFormat;
  }

  final String solrA;
  final String solrB;
  final String collectionA;
  final String collectionB;
  final String collectoryUrl;
  final bool compareDrs;
  final bool compareSpecies;
  final bool truncateSpecies;
  final bool compareInst;
  final bool compareLayers;
  final bool compareHubs;
  final bool csvFormat;
  final String totals = 'totals';
  final List<String> titleS = <String>[];
  Map<String, Result> results = {};
  final List<String> solrS = <String>[];
  final List<String> collectionS = <String>[];

  Future<void> run() async {
    if (compareDrs) {
      await queryTotals(solrS, '/select',
          {'q': '*:*', 'rows': '0', 'wt': 'json', 'facet': 'false'});
      List<dynamic> resources =
          await urlGet(collectoryUrl, '/ws/dataResource', {}) as List<dynamic>;
      for (var dr in resources) {
        results.putIfAbsent(dr['uid'], () => Result.empty(dr['uid']));
      }
      await getDrTotals();

      printHeader();
      printSorted();
      int a = 0;
      int b = 0;
      for (var r in results.values) {
        if (r.key != totals) {
          a = a + r.a;
          b = b + r.b;
        }
      }
      Result mapped = Result('Mapped', a).setB(b);
      // print(mapped);
      Result unmapped = Result('Unmapped', results.entries.first.value.a - a)
          .setB(results.entries.first.value.b - b);
      // print(unmapped);
      var diff = Map.from(results)..removeWhere((e, v) => v.d != 0);
      //print("results size: ${diff.length}");
      reset();
    }
    if (compareSpecies) {
      await getFieldDiff('taxon_name', 'scientificName');
      if (truncateSpecies) {
        results
            .removeWhere((String k, Result v) => v.d < 10000 && v.d > -10000);
      }
      printHeader();
      printSorted();
      reset();
    }

    if (compareInst) {
      await getFieldDiff('institution_name', 'institutionName');
      printHeader();
      printSorted();
      reset();
    }
    if (compareLayers) {
      await getFieldDiff('cl2', 'cl2');
      await getFieldDiff('cl3', 'cl3');
      await getFieldDiff('cl6', 'cl6');
      printHeader();
      printSorted();
      reset();
    }
    if (compareHubs) {
      await getFieldDiff('data_hub_uid', 'dataHubUid');
      printHeader();
      printSorted();
      reset();
    }
  }

  void printHeader() {
    if (csvFormat) {
      print(';biocache-store;pipelines;difference');
    } else {
      print('|  |  ${titleS[0]}  | ${titleS[1]} | difference |');
      print(
          '| ------------- | ------------- | ------------- | ------------- |');
    }
  }

  void reset() {
    results = {};
    print('');
    print('');
  }

  void printSorted() {
    List<Result> sorted = results.values.toList();
    sorted.sort((a, b) => a.d.compareTo(b.d));
    for (var r in sorted) {
      if (r.d != 0) print(r);
    }
  }

  Future<List> getDrTotals() async {
    return await Future.wait(solrS.mapIndexed((i, solrBase) async {
      String field = await isAPipelinesIndex(solrBase, collectionS[i])
          ? 'dataResourceUid'
          : 'data_resource_uid';
      Map<String, dynamic> response = await getFacetData(
          solrBase: solrBase,
          collection: collectionS[i],
          q: '$field:*',
          facetField: field,
          faceLimit: -1,
          sort: "index");
      Map<String, dynamic> drs = response['facet_counts']['facet_fields'][field]
          as Map<String, dynamic>;
      for (var e in drs.entries) {
        String key;
        if (!results.containsKey(e.key)) {
          // print("${e.key} not found in collectory");
          key = "~~${e.key}~~";
          results.putIfAbsent(key, () => Result(key, 0));
        } else {
          key = e.key;
        }
        if (i == 0) {
          results.update(key, (el) => el.setA(e.value));
        } else {
          results.update(key, (el) => el.setB(e.value));
        }
      }
    }));
  }

  Future<List> getFieldDiff(String bStoreField, String pipelinesField) async {
    return await Future.wait(solrS.mapIndexed((i, solrBase) async {
      String field = await isAPipelinesIndex(solrBase, collectionS[i])
          ? pipelinesField
          : bStoreField;
      Map<String, dynamic> response = await getFacetData(
          solrBase: solrBase,
          collection: collectionS[i],
          q: '$field:*',
          facetField: field,
          faceLimit: -1,
          sort: "index");
      Map<String, dynamic> results = response['facet_counts']['facet_fields']
          [field] as Map<String, dynamic>;
      for (var entry in results.entries) {
        storeResults(entry.key, entry.value, i);
      }
    }));
  }

  Future<bool> isAPipelinesIndex(String solrBase, String collection) async {
    Uri uri = Uri.https(solrBase, '/solr/$collection/select',
        {'q': '*:*', 'wt': 'csv', 'rows': '0', 'facet': '', 'fl': 'data*'});
    Response response = await http.get(uri);
    return response.body.contains("dataResourceUid");
  }

  Future<List<void>> queryTotals(
      List<String> solrS, String query, Map<String, String> params) async {
    return await Future.wait(solrS.mapIndexed((i, solrBase) async {
      Map<String, dynamic> response =
          await urlGet(solrBase, "/solr/${collectionS[i]}$query", params)
              as Map<String, dynamic>;
      storeResults(totals, response["response"]["numFound"], i);
    }));
  }

  Future<Map<String, dynamic>> getFacetData(
      {required String solrBase,
      required String collection,
      required String q,
      required String facetField,
      required int faceLimit,
      required String sort}) async {
    return await urlGet(solrBase, "/solr/$collection/select", {
      'q': q,
      'rows': '0',
      'wt': 'json',
      'facet.field': facetField,
      'facet': 'on',
      'facet.limit': faceLimit.toString(),
      'json.nl': 'map',
      "facet.sort": sort
    }) as Map<String, dynamic>;
  }

  void storeResults(String key, int num, int index) {
    if (!results.containsKey(key)) {
      results.putIfAbsent(key, () => Result.empty(key));
    }
    if (index == 0) {
      results.update(key, (el) => el.setA(num));
    } else {
      results.update(key, (el) => el.setB(num));
    }
  }

  Future<dynamic> urlGet(String base, String path, Map<String, String> params,
      [debug = false]) async {
    Uri uri =
        params.isEmpty ? Uri.https(base, path) : Uri.https(base, path, params);
    if (debug) {
      print("INFO: Reading url: " + uri.toString());
    }
    try {
      Response response = await http.get(uri);
      return jsonDecode(response.body);
    } catch (all) {
      _handleError('Error reading url: ' + uri.toString() + all.toString());
      rethrow;
    }
  }

  void _handleError(String msg) async {
    stderr.writeln(msg);
    exit(2);
  }
}

class Result {
  static bool csvFormat = false;

  final String key;
  int a;
  int b;

  int get d => b - a;

  Result(this.key, this.a) : b = 0;

  Result.empty(this.key)
      : a = 0,
        b = 0;

  @override
  String toString() => csvFormat
      ? "$key;${_f(a)};${_f(b)};${d > 0 ? '+' : ''}${_f(d)}"
      : "|$key|${_f(a)}|${_f(b)}|${d > 0 ? '+' : ''}${_f(d)}|";

  Result setA(int a) {
    this.a = a;
    return this;
  }

  Result setB(int b) {
    this.b = b;
    return this;
  }

  String _f(int n) =>
      intl.NumberFormat.decimalPattern(Platform.localeName).format(n);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Result && runtimeType == other.runtimeType && key == other.key;

  @override
  int get hashCode => key.hashCode ^ a.hashCode ^ b.hashCode;
}
