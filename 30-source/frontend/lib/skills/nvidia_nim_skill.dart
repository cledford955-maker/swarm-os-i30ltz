import 'package:flutter/foundation.dart';

/// A declarative skill that can be fulfilled by an NVIDIA NIM endpoint.
///
/// Skills are provider-agnostic descriptions of a capability. The [SkillRouter]
/// maps a requested skill to a concrete [NimSkillModel] at runtime, preferring
/// free NVIDIA NIM endpoints and falling back to paid OpenRouter models when
/// the free tier is unavailable or the model is removed from the live catalog.
@immutable
class NimSkill {
  final String id;
  final String name;
  final String description;

  /// Canonical NVIDIA NIM model ID used on the free OpenRouter NIM endpoint.
  /// Example: `nvidia/parakeet-ctc-1.1b:free`
  final String defaultModelId;

  /// Fallback model ID if the free NIM is removed or rate-limited.
  final String? fallbackModelId;

  /// OpenRouter-style modality tag used for routing to the right endpoint.
  final NimSkillModality modality;

  /// Expected input shape for validation and UI generation.
  final NimSkillSchema inputSchema;

  /// Expected output shape for parsing and UI generation.
  final NimSkillSchema outputSchema;

  /// Cost tier hint for the skill router.
  final NimSkillCostTier costTier;

  /// Maximum tokens/payload size hint (model-specific).
  final String? contextWindow;

  /// Keywords for agent matching and search.
  final List<String> keywords;

  const NimSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultModelId,
    this.fallbackModelId,
    required this.modality,
    required this.inputSchema,
    required this.outputSchema,
    this.costTier = NimSkillCostTier.free,
    this.contextWindow,
    this.keywords = const [],
  });

  /// Returns the model ID to use given an optional override and a predicate
  /// that tells us whether a model ID is currently available.
  String resolveModelId({
    String? overrideModelId,
    required bool Function(String id) isAvailable,
  }) {
    final candidates = [
      if (overrideModelId != null) overrideModelId,
      defaultModelId,
      if (fallbackModelId != null) fallbackModelId!,
    ];
    for (final id in candidates) {
      if (isAvailable(id)) return id;
    }
    // If nothing is available, return the default so the caller can surface
    // a clean "model unavailable" error rather than a null crash.
    return defaultModelId;
  }
}

/// High-level modality of a NIM skill. Determines which OpenRouter endpoint
/// and request/response format the skill router uses.
enum NimSkillModality {
  /// Chat/completion-style models.
  chat,

  /// Speech-to-text models (OpenRouter `/audio/transcriptions`).
  speechToText,

  /// Text-to-speech models (OpenRouter `/audio/speech`).
  textToSpeech,

  /// Embedding models (OpenRouter `/embeddings`).
  embeddings,

  /// Reranking models (OpenRouter `/rerank`).
  rerank,

  /// Image generation models (OpenRouter `/images/generations`).
  image,

  /// Structured optimization / simulation models that use chat-style JSON.
  structuredChat,
}

/// Cost tier used by the skill router to decide whether a skill can be invoked
/// automatically or needs explicit user confirmation.
enum NimSkillCostTier {
  /// Free NVIDIA NIM endpoint. Safe to invoke automatically.
  free,

  /// Low-cost paid endpoint. May be invoked automatically for important agents.
  low,

  /// Standard paid endpoint. Requires user confirmation or a budget flag.
  standard,

  /// Expensive endpoint. Always requires explicit approval.
  premium,
}

/// A primitive schema field for skill inputs/outputs.
@immutable
class NimSkillField {
  final String name;
  final NimSkillFieldType type;
  final String description;
  final bool required;
  final dynamic defaultValue;

  const NimSkillField({
    required this.name,
    required this.type,
    required this.description,
    this.required = true,
    this.defaultValue,
  });
}

enum NimSkillFieldType {
  string,
  text,
  audioFile,
  imageFile,
  imageUrl,
  stringList,
  number,
  boolean,
  json,
}

/// Input or output schema for a skill.
@immutable
class NimSkillSchema {
  final List<NimSkillField> fields;

  const NimSkillSchema({required this.fields});
}

/// Canonical registry of NVIDIA NIM-backed skills available to agents.
///
/// Add new skills here; the skill router and agent definitions reference them
/// by [NimSkill.id].
class NvidiaNimSkillRegistry {
  NvidiaNimSkillRegistry._();

  static const _speechToText = NimSkill(
    id: 'nvidia.stt',
    name: 'NVIDIA Parakeet Speech-to-Text',
    description:
        'Convert audio to text using NVIDIA Parakeet CTC. Optimized for '
        'English and accented speech.',
    defaultModelId: 'nvidia/parakeet-ctc-1.1b:free',
    modality: NimSkillModality.speechToText,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'audio',
          type: NimSkillFieldType.audioFile,
          description: 'Audio file to transcribe (wav/mp3/flac).',
        ),
        NimSkillField(
          name: 'language',
          type: NimSkillFieldType.string,
          description: 'Optional language hint (default: en).',
          required: false,
          defaultValue: 'en',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'text',
          type: NimSkillFieldType.text,
          description: 'Transcribed text.',
        ),
      ],
    ),
    contextWindow: 'Stream',
    keywords: ['nvidia', 'parakeet', 'stt', 'speech', 'audio'],
  );

  static const _textToSpeech = NimSkill(
    id: 'nvidia.tts',
    name: 'NVIDIA Riva FastPitch TTS',
    description:
        'Synthesize natural speech from text using NVIDIA Riva FastPitch.',
    defaultModelId: 'nvidia/riva-tts-fastpitch:free',
    modality: NimSkillModality.textToSpeech,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'text',
          type: NimSkillFieldType.text,
          description: 'Text to speak.',
        ),
        NimSkillField(
          name: 'voice',
          type: NimSkillFieldType.string,
          description: 'Voice identifier.',
          required: false,
          defaultValue: 'default',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'audio',
          type: NimSkillFieldType.audioFile,
          description: 'Generated audio file path or bytes.',
        ),
      ],
    ),
    contextWindow: 'Stream',
    keywords: ['nvidia', 'riva', 'tts', 'speech', 'audio'],
  );

  static const _embeddings = NimSkill(
    id: 'nvidia.embeddings',
    name: 'NVIDIA NV-Embed-QA 4',
    description:
        'Generate high-dimensional vector embeddings for RAG and memory retrieval.',
    defaultModelId: 'nvidia/embeddings-nv-embed-qa-4:free',
    modality: NimSkillModality.embeddings,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'inputs',
          type: NimSkillFieldType.stringList,
          description: 'List of text chunks to embed.',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'embeddings',
          type: NimSkillFieldType.json,
          description: 'List of embedding vectors.',
        ),
      ],
    ),
    contextWindow: '512',
    keywords: ['nvidia', 'embeddings', 'rag', 'vector', 'memory'],
  );

  static const _rerank = NimSkill(
    id: 'nvidia.rerank',
    name: 'NVIDIA NV-Embed Rerank Large',
    description:
        'Rerank retrieved chunks against a query using a cross-encoder.',
    defaultModelId: 'nvidia/reranking-nv-embed-rerank-large:free',
    modality: NimSkillModality.rerank,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'query',
          type: NimSkillFieldType.text,
          description: 'User query.',
        ),
        NimSkillField(
          name: 'documents',
          type: NimSkillFieldType.stringList,
          description: 'Candidate chunks to rerank.',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'rankings',
          type: NimSkillFieldType.json,
          description: 'Ordered list of document indices with scores.',
        ),
      ],
    ),
    contextWindow: '512',
    keywords: ['nvidia', 'rerank', 'rag', 'search'],
  );

  static const _imageGeneration = NimSkill(
    id: 'nvidia.image',
    name: 'NVIDIA SDXL Turbo Image Generation',
    description:
        'Generate images from text prompts using SDXL Turbo on NVIDIA NIM.',
    defaultModelId: 'nvidia/diffusers-sdxl-turbo:free',
    modality: NimSkillModality.image,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'prompt',
          type: NimSkillFieldType.text,
          description: 'Image prompt.',
        ),
        NimSkillField(
          name: 'size',
          type: NimSkillFieldType.string,
          description: 'Image size (default: 512x512).',
          required: false,
          defaultValue: '512x512',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'image',
          type: NimSkillFieldType.imageUrl,
          description: 'URL or local path to generated image.',
        ),
      ],
    ),
    contextWindow: '512x512',
    keywords: ['nvidia', 'sdxl', 'image', 'generation', 'diffusion'],
  );

  static const _optimization = NimSkill(
    id: 'nvidia.cuopt',
    name: 'NVIDIA cuOpt Combinatorial Solver',
    description:
        'Solve scheduling, routing, and resource allocation problems with '
        'GPU-accelerated combinatorial optimization.',
    defaultModelId: 'nvidia/cuopt-v1:free',
    modality: NimSkillModality.structuredChat,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'problem',
          type: NimSkillFieldType.json,
          description: 'Problem definition (cost matrix, constraints, demands).',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'solution',
          type: NimSkillFieldType.json,
          description: 'Optimized assignment/routing plan.',
        ),
      ],
    ),
    contextWindow: 'Solver',
    keywords: ['nvidia', 'cuopt', 'solver', 'optimization', 'scheduling'],
  );

  static const _worldModel = NimSkill(
    id: 'nvidia.cosmos',
    name: 'NVIDIA Cosmos World Model',
    description:
        'Reason about physical AI scenarios and world dynamics using Cosmos Nemotron.',
    defaultModelId: 'nvidia/cosmos-nemotron-340b:free',
    fallbackModelId: 'nvidia/llama-3.1-nemotron-70b-instruct:free',
    modality: NimSkillModality.chat,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'prompt',
          type: NimSkillFieldType.text,
          description: 'Physical scenario description or question.',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'response',
          type: NimSkillFieldType.text,
          description: 'Reasoning about the physical scenario.',
        ),
      ],
    ),
    contextWindow: 'Simulation',
    keywords: ['nvidia', 'cosmos', 'physics', 'world model'],
  );

  static const _usdReasoning = NimSkill(
    id: 'nvidia.omniverse',
    name: 'NVIDIA Omniverse USD Asset Reasoner',
    description:
        'Parse and reason about Universal Scene Description (USD) assets and 3D pipelines.',
    defaultModelId: 'nvidia/omniverse-asset-reasoner-70b:free',
    modality: NimSkillModality.chat,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'usdSnippet',
          type: NimSkillFieldType.text,
          description: 'USD text snippet or asset description.',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'response',
          type: NimSkillFieldType.text,
          description: 'USD analysis or pipeline suggestion.',
        ),
      ],
    ),
    contextWindow: '32K',
    keywords: ['nvidia', 'omniverse', 'usd', '3d', 'asset'],
  );

  static const _nemotronEval = NimSkill(
    id: 'nvidia.nemotron.eval',
    name: 'NVIDIA Nemotron System Eval',
    description:
        'Run system evaluations, hardware profiling, and optimization analysis.',
    defaultModelId: 'nvidia/nemotron-3-ultra-550b-a55b:free',
    fallbackModelId: 'nvidia/llama-3.1-nemotron-70b-instruct:free',
    modality: NimSkillModality.chat,
    inputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'context',
          type: NimSkillFieldType.text,
          description: 'System context, logs, or metrics to evaluate.',
        ),
      ],
    ),
    outputSchema: NimSkillSchema(
      fields: [
        NimSkillField(
          name: 'evaluation',
          type: NimSkillFieldType.text,
          description: 'Structured evaluation and recommendations.',
        ),
      ],
    ),
    contextWindow: '256K',
    keywords: ['nvidia', 'nemotron', 'eval', 'system', 'optimization'],
  );

  static const List<NimSkill> all = [
    _speechToText,
    _textToSpeech,
    _embeddings,
    _rerank,
    _imageGeneration,
    _optimization,
    _worldModel,
    _usdReasoning,
    _nemotronEval,
  ];

  static NimSkill? byId(String id) {
    for (final skill in all) {
      if (skill.id == id) return skill;
    }
    return null;
  }

  static List<NimSkill> byKeyword(String keyword) {
    final lower = keyword.toLowerCase();
    return all.where((s) {
      return s.keywords.any((k) => k.toLowerCase().contains(lower)) ||
          s.name.toLowerCase().contains(lower);
    }).toList();
  }
}
