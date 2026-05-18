// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_alloy_suppression.dart';

const _tracerName = 'dartastic_otel_libs_alloy';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class AlloyResult {
  const AlloyResult({
    this.entityToken,
    this.evaluationToken,
    this.outcome,
    this.workflowToken,
    this.servicesRun,
    this.dataSourcesRun,
    this.journeyApplicationToken,
    this.journeyStatus,
    this.entityType,
    this.requestId,
    this.statusCode,
  });

  /// `entity_token` for the subject.
  final String? entityToken;

  /// `evaluation_token`.
  final String? evaluationToken;

  /// `Approved` / `Denied` / `Manual Review` / `Resubmit Document`.
  final String? outcome;

  /// Workflow token used for the decision.
  final String? workflowToken;

  /// Comma-joined service names invoked (each service is metered).
  final String? servicesRun;

  /// Number of external data sources called — Alloy's primary cost
  /// dim since each data source is billed independently.
  final int? dataSourcesRun;

  /// Journey application token (Alloy Journeys orchestration product).
  final String? journeyApplicationToken;

  /// `in_progress` / `approved` / `denied` / `manual_review` /
  /// `pending`.
  final String? journeyStatus;

  /// `Person` / `Business`.
  final String? entityType;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class AlloyCallResult<T> {
  const AlloyCallResult({required this.value, this.result});
  final T value;
  final AlloyResult? result;
}

/// Wraps an Alloy API call in a CLIENT span. [operation] is one of
/// `entities.create`, `entities.get`, `entities.search`,
/// `evaluations.create`, `evaluations.get`, `evaluations.list`,
/// `journey_applications.create`, `journey_applications.get`,
/// `journey_applications.update`, `documents.upload`, `webhooks.list`,
/// `webhooks.create`, `groups.list`.
Future<T> tracedAlloy<T>({
  required String operation,
  required Future<AlloyCallResult<T>> Function() invoke,
}) async {
  if (alloyInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'alloy',
    'rpc.method': operation,
    'alloy.operation': operation,
  };

  final span = _tracer().startSpan(
    'alloy $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.entityToken != null) {
        extras.add(OTel.attributeString(
          'alloy.entity.token',
          r.result!.entityToken!,
        ));
      }
      if (r.result!.evaluationToken != null) {
        extras.add(OTel.attributeString(
          'alloy.evaluation.token',
          r.result!.evaluationToken!,
        ));
      }
      if (r.result!.outcome != null) {
        extras.add(OTel.attributeString(
          'alloy.outcome',
          r.result!.outcome!,
        ));
        if (r.result!.outcome == 'Denied') {
          span.setStatus(
            SpanStatusCode.Error,
            'Alloy denied',
          );
        }
      }
      if (r.result!.workflowToken != null) {
        extras.add(OTel.attributeString(
          'alloy.workflow.token',
          r.result!.workflowToken!,
        ));
      }
      if (r.result!.servicesRun != null) {
        extras.add(OTel.attributeString(
          'alloy.services_run',
          r.result!.servicesRun!,
        ));
      }
      if (r.result!.dataSourcesRun != null) {
        extras.add(OTel.attributeInt(
          'alloy.data_sources_run',
          r.result!.dataSourcesRun!,
        ));
      }
      if (r.result!.journeyApplicationToken != null) {
        extras.add(OTel.attributeString(
          'alloy.journey_application.token',
          r.result!.journeyApplicationToken!,
        ));
      }
      if (r.result!.journeyStatus != null) {
        extras.add(OTel.attributeString(
          'alloy.journey.status',
          r.result!.journeyStatus!,
        ));
      }
      if (r.result!.entityType != null) {
        extras.add(OTel.attributeString(
          'alloy.entity.type',
          r.result!.entityType!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'alloy.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Alloy HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
