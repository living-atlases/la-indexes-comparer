import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:intl/intl.dart' as intl;

const solrA = 'admin3a21:ad3ed32ada@index.gbif.es';
const solrB = 'admin3a21:ad3ed32ada@indexp.gbif.es';
const String collectoryUrl = 'colecciones.gbif.es';
const List<String> solrS = [solrA, solrB];
const collection = 'biocache';
const totals = 'totals';
const bool compareDrs = true;
const bool compareSpecies = true;
const bool compareInst = true;
const bool compareLayers = true;
const bool csvFormat = true;

Map<String, Result> results = {};

Future<void> main(List<String> arguments) async {
  exitCode = 0; // presume success
  final parser = ArgParser()..addFlag('solr-a', negatable: false, abbr: 'a');
  ArgResults argResults = parser.parse(arguments);

  if (compareDrs) {
    await queryTotals(solrS, '/select',
        {'q': '*:*', 'rows': '0', 'wt': 'json', 'facet': 'false'});
    List<dynamic> resources =
        await urlGet(collectoryUrl, '/ws/dataResource', {}) as List<dynamic>;
    for (var dr in resources) {
      results.putIfAbsent(dr['uid'], () => Result.empty(dr['uid']));
    }
    await getDrTotals(solrS, collection);

    if (csvFormat) {
      print(';biocache-store;pipelines;difference');
    } else {
      print('|  |  biocache-store  | pipelines | difference |');
      print('| ------------- | ------------- | ------------- |');
    }
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
    print(mapped);
    Result unmapped = Result('Unmapped', results.entries.first.value.a - a)
        .setB(results.entries.first.value.b - b);
    print(unmapped);
    var diff = Map.from(results)..removeWhere((e, v) => v.d != 0);
    print("results size: ${diff.length}");
    reset();
  }
  if (compareSpecies) {
    await getFieldDiff('taxon_name', 'scientificName');
    printSorted();
    reset();
  }

  if (compareInst) {
    await getFieldDiff('institution_name', 'institutionName');
    printSorted();
    reset();
  }
  if (compareLayers) {
    await getFieldDiff('cl2', 'cl2');
    await getFieldDiff('cl3', 'cl3');
    await getFieldDiff('cl6', 'cl6');
    printSorted();
    reset();
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

Future<List> getDrTotals(List<String> solrS, String collection) async {
  return await Future.wait(solrS.map((solrBase) async {
    int i = solrS.indexOf(solrBase);
    String field = await isAPipelinesIndex(solrBase, collection)
        ? 'dataResourceUid'
        : 'data_resource_uid';
    Map<String, dynamic> response = await getFacetData(
        solrBase: solrBase,
        collection: collection,
        q: '$field:*',
        facetField: field,
        faceLimit: -1,
        sort: "index");
    Map<String, dynamic> drs =
        response['facet_counts']['facet_fields'][field] as Map<String, dynamic>;
    for (var e in drs.entries) {
      String key;
      if (!results.containsKey(e.key)) {
        print("${e.key} not found in collectory");
        key = "*${e.key}*";
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
  return await Future.wait(solrS.map((solrBase) async {
    String field = await isAPipelinesIndex(solrBase, collection)
        ? pipelinesField
        : bStoreField;
    Map<String, dynamic> response = await getFacetData(
        solrBase: solrBase,
        collection: collection,
        q: '$field:*',
        facetField: field,
        faceLimit: -1,
        sort: "index");
    Map<String, dynamic> results =
        response['facet_counts']['facet_fields'][field] as Map<String, dynamic>;
    for (var entry in results.entries) {
      storeResults(entry.key, entry.value);
    }
  }));
}

Future<bool> isAPipelinesIndex(String solrBase, String collection) async {
  Uri uri = Uri.https(solrBase, '/solr/$collection/select',
      {'q': '*:*', 'wt': 'csv', 'rows': '0', 'facet': '', 'fl': 'data*'});
  Response response = await http.get(uri);
  return response.body.contains("dataResourceUid");
}

Future<void> queryTotals(
    List<String> solrS, String query, Map<String, String> params) async {
  await Future.wait(solrS.map((solrBase) async {
    Map<String, dynamic> response =
        await urlGet(solrBase, "/solr/$collection$query", params)
            as Map<String, dynamic>;
    storeResults(totals, response["response"]["numFound"]);
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

void storeResults(String key, int num) {
  if (!results.containsKey(key)) {
    results.putIfAbsent(key, () => Result(key, num));
  } else {
    results.update(key, (r) => r.setB(num));
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

class Result {
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
