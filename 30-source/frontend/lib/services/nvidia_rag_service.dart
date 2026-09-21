import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/agent.dart';
import '../skills/nvidia_nim_skill.dart';
import 'skill_router.dart';

/// A single embedding vector returned by the NVIDIA NV-Embed-QA NIM.
typedef EmbeddingVector = List<double>;

/// A ranked document returned by the NVIDIA NV-Embed Rerank NIM.
@immutable
class RankedDocument {
  final int index;
  final double score;
  final String document;

  const RankedDocument({
    required this.index,
    required this.score,
    required this.document,
  });
}

/// Typed facade over [SkillRouter] for NVIDIA RAG primitives:
/// embeddings and reranking.
///
/// Use this from memory backends, the Librarian, Lucille, or any agent that
/// needs semantic retrieval without touching raw skill maps.
class NvidiaRagService {
  final SkillRouter _router;

  const NvidiaRagService(this._router);

  /// Embed a list of text chunks using the NVIDIA NV-Embed-QA 4 NIM.
  ///
  /// Returns a list of vectors in the same order as [chunks].
  Future<List<EmbeddingVector>> embedChunks({
    required Agent agent,
    required List<String> chunks,
  }) async {
    if (chunks.isEmpty) return [];
    final skill = NvidiaNimSkillRegistry.byId('nvidia.embeddings')!;
    final result = await _router.execute(
      agent: agent,
      skill: skill,
      inputs: {'inputs': chunks},
    );
    final raw = result['embeddings'] as List<dynamic>? ?? [];
    return raw
        .map((v) => (v as List<dynamic>).map((n) => (n as num).toDouble()).toList())
        .toList();
  }

  /// Embed a single query string.
  Future<EmbeddingVector> embedQuery(Agent agent, String query) async {
    final vectors = await embedChunks(agent: agent, chunks: [query]);
    if (vectors.isEmpty) return [];
    return vectors.first;
  }

  /// Rerank [documents] against [query] using the NVIDIA NV-Embed Rerank NIM.
  ///
  /// Returns documents ordered by descending relevance score.
  Future<List<RankedDocument>> rerank({
    required Agent agent,
    required String query,
    required List<String> documents,
    int? topK,
  }) async {
    if (query.trim().isEmpty || documents.isEmpty) return [];
    final skill = NvidiaNimSkillRegistry.byId('nvidia.rerank')!;
    final result = await _router.execute(
      agent: agent,
      skill: skill,
      inputs: {'query': query, 'documents': documents},
    );
    final raw = result['rankings'] as List<dynamic>? ?? [];
    final ranked = raw
        .map((e) {
          final map = e as Map<String, dynamic>;
          final index = map['index'] as int? ?? 0;
          return RankedDocument(
            index: index,
            score: (map['score'] as num?)?.toDouble() ?? 0.0,
            document: documents[index],
          );
        })
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (topK != null && topK >= 0) {
      return ranked.sublist(0, math.min(topK, ranked.length));
    }
    return ranked;
  }

  /// Convenience: embed with the default RAG agent (`librarian`).
  Future<List<EmbeddingVector>> embedWithDefaultAgent(List<String> chunks) {
    final agent = getAgent('librarian') ?? agents.first;
    return embedChunks(agent: agent, chunks: chunks);
  }

  /// Convenience: rerank with the default RAG agent (`librarian`).
  Future<List<RankedDocument>> rerankWithDefaultAgent({
    required String query,
    required List<String> documents,
    int? topK,
  }) {
    final agent = getAgent('librarian') ?? agents.first;
    return rerank(agent: agent, query: query, documents: documents, topK: topK);
  }
}
