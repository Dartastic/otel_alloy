// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_alloy/otel_alloy.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_alloy-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('evaluations.create records services + data sources + outcome',
      () async {
    await tracedAlloy<String>(
      operation: 'evaluations.create',
      invoke: () async => const AlloyCallResult(
        value: 'ok',
        result: AlloyResult(
          entityToken: 'e-1',
          evaluationToken: 'eval-1',
          outcome: 'Approved',
          workflowToken: 'wf-1',
          servicesRun: 'KYC,KYB,Watchlist',
          dataSourcesRun: 7,
          entityType: 'Person',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('alloy evaluations.create')!);
    expect(a['alloy.entity.token'], 'e-1');
    expect(a['alloy.evaluation.token'], 'eval-1');
    expect(a['alloy.outcome'], 'Approved');
    expect(a['alloy.services_run'], 'KYC,KYB,Watchlist');
    expect(a['alloy.data_sources_run'], 7);
    expect(a['alloy.entity.type'], 'Person');
  });

  test('Denied sets span error', () async {
    await tracedAlloy<String>(
      operation: 'evaluations.get',
      invoke: () async => const AlloyCallResult(
        value: 'ok',
        result: AlloyResult(outcome: 'Denied'),
      ),
    );
    expect(
      spans.findSpanByName('alloy evaluations.get')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutAlloyInstrumentationAsync(() async {
      await tracedAlloy<String>(
        operation: 'entities.search',
        invoke: () async => const AlloyCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('alloy '), isEmpty);
  });
}
