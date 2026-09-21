import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model Tier matching TypeScript SwarmModel
enum ModelTier { offline, freeOnline, paidOnline }

/// Provider matching TypeScript SwarmModel
enum ProviderId { ollama, nvidia, openrouter }

/// Definition of an AI Model within a Swarm
class SwarmModel {
  final String id;
  final String name;
  final String role;
  final ProviderId provider;
  final ModelTier tier;
  final String? pricePer1M;
  final String? originalPricePer1M;
  final bool isOnSale;
  final String? saleDiscount;
  final String? contextWindow;
  final String description;
  final List<String> keywords;

  const SwarmModel({
    required this.id,
    required this.name,
    required this.role,
    required this.provider,
    required this.tier,
    this.pricePer1M,
    this.originalPricePer1M,
    this.isOnSale = false,
    this.saleDiscount,
    this.contextWindow,
    required this.description,
    this.keywords = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'provider': provider.name,
    'tier': tier.name,
    'pricePer1M': pricePer1M,
    'originalPricePer1M': originalPricePer1M,
    'isOnSale': isOnSale,
    'saleDiscount': saleDiscount,
    'contextWindow': contextWindow,
    'description': description,
    'keywords': keywords,
  };

  factory SwarmModel.fromJson(Map<String, dynamic> json) => SwarmModel(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    provider: ProviderId.values.firstWhere((e) => e.name == json['provider'], orElse: () => ProviderId.openrouter),
    tier: ModelTier.values.firstWhere((e) => e.name == json['tier'], orElse: () => ModelTier.paidOnline),
    pricePer1M: json['pricePer1M'] as String?,
    originalPricePer1M: json['originalPricePer1M'] as String?,
    isOnSale: json['isOnSale'] as bool? ?? false,
    saleDiscount: json['saleDiscount'] as String?,
    contextWindow: json['contextWindow'] as String?,
    description: json['description'] as String? ?? '',
    keywords: (json['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

/// A collection of models configured for a specific role
class SwarmConfig {
  final String id;
  final String name;
  final String role;
  final List<SwarmModel> models;
  final String? estimatedPrice;
  final bool isDefault;
  final bool isCustom;
  final String? description;

  const SwarmConfig({
    required this.id,
    required this.name,
    required this.role,
    required this.models,
    this.estimatedPrice,
    this.isDefault = false,
    this.isCustom = false,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'models': models.map((m) => m.toJson()).toList(),
    'estimatedPrice': estimatedPrice,
    'isDefault': isDefault,
    'isCustom': isCustom,
    'description': description,
  };

  factory SwarmConfig.fromJson(Map<String, dynamic> json) => SwarmConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    models: ((json['models'] as List<dynamic>?) ?? [])
        .map((m) => SwarmModel.fromJson(m as Map<String, dynamic>))
        .toList(),
    estimatedPrice: json['estimatedPrice'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
    isCustom: json['isCustom'] as bool? ?? true,
    description: json['description'] as String?,
  );
}

/// Complete Catalog of All Models (Flagship, NVIDIA NIM 70, OpenRouter Top 50, Local)
final allModels = <SwarmModel>[
  // ─── Flagship Default Swarm Models ─────────────────────────────
  const SwarmModel(id: 'anthropic/claude-opus-4.6', name: 'Claude Opus 4.6', role: 'Leader / Orchestrator', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$5.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'Handles root dependency mapping, breaking architectural goals into discrete, non-conflicting issues.', keywords: ['leader', 'orchestrator', 'claude', 'architecture']),
  const SwarmModel(id: 'openai/gpt-5.6-sol', name: 'GPT-5.6 Sol', role: 'Systems & Backend Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$3.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '256K', description: 'Writes core systems logic, algorithm pipelines, and multi-file low-level changes.', keywords: ['systems', 'backend', 'algorithms', 'gpt5']),
  const SwarmModel(id: 'moonshotai/kimi-k3', name: 'Kimi K3', role: 'Frontend & Layout Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.40 / 1M', originalPricePer1M: r'$0.60 / 1M', isOnSale: true, saleDiscount: '33% OFF', contextWindow: '200K', description: 'Implements state management, UI layouts, and reactive client views.', keywords: ['frontend', 'ui', 'state', 'kimi', 'sale']),
  const SwarmModel(id: 'deepseek/deepseek-v4-pro', name: 'DeepSeek-V4 Pro', role: 'Tool, Shell & AST Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.20 / 1M', originalPricePer1M: r'$0.35 / 1M', isOnSale: true, saleDiscount: '40% OFF', contextWindow: '128K', description: 'Executes environment operations, generates AST diffs, and orchestrates automated terminal runs.', keywords: ['tools', 'shell', 'ast', 'terminal', 'deepseek', 'sale']),
  const SwarmModel(id: 'google/gemini-3.7-flash', name: 'Gemini 3.7 Flash / Haiku 4.5', role: 'QA & Verification Loop', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.10 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1M', description: 'Rapidly runs test matrices, checks linter diagnostics, and catches regression errors before merging.', keywords: ['qa', 'verification', 'testing', 'gemini', 'haiku']),
  const SwarmModel(id: 'zhipu/glm-5.2-autocomplete', name: 'GLM 5.2 Auto-Complete', role: 'Auto-Complete Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.08 / 1M', originalPricePer1M: r'$0.15 / 1M', isOnSale: true, saleDiscount: '45% OFF', contextWindow: '64K', description: 'High-speed inline code completion, syntax inference, and token streaming.', keywords: ['autocomplete', 'inline', 'glm', 'streaming', 'sale']),
  const SwarmModel(id: 'nvidia/nemotron-120b-ultra', name: 'Nemotron Ultra', role: 'System Evals & Optimization', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'NVIDIA flagship ultra model for automated system evaluations, hardware profiling, latency benchmarking, and multi-agent token optimization.', keywords: ['nvidia', 'nemotron', 'ultra', 'evals', 'optimization', 'sysopt', 'hardware', 'profiling']),

  // ─── High-Efficiency Budget UI & Coding/Eval Models ──────────────
  const SwarmModel(id: 'google/gemini-2.0-flash-lite', name: 'Gemini 2.0 Flash Lite', role: 'Budget UI & Wireframe Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.075 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1M', description: 'Ultra cost-effective multimodal UI layout generator, Flutter widget composer, and rapid screen architect.', keywords: ['ui', 'wireframe', 'gemini', 'budget', 'cheap', 'flutter']),
  const SwarmModel(id: 'qwen/qwen-2.5-vl-7b-instruct', name: 'Qwen 2.5 VL 7B', role: 'Visual UI & Layout Inspector', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.08 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Compact multimodal vision model for verifying UI mockups, inspecting widget alignment, and CSS/Flutter aesthetics.', keywords: ['ui', 'vision', 'layout', 'qwen', 'budget']),
  const SwarmModel(id: 'deepseek/deepseek-chat', name: 'DeepSeek V3 (Budget Coder)', role: 'Budget Systems & AST Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.14 / 1M', originalPricePer1M: r'$0.28 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: '671B MoE model delivering near-R1 code synthesis and multi-file patching at 1/10th the cost.', keywords: ['deepseek', 'v3', 'coding', 'budget', 'cheap', 'sale']),
  const SwarmModel(id: 'zhipu/glm-4-flash', name: 'GLM-4 Flash (Rapid Eval)', role: 'High-Speed Log & Code Evaluator', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.05 / 1M', originalPricePer1M: r'$0.10 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'Ultra-low cost triage and verification engine for running test matrices, compiler diagnostics, and AST sanity proofs.', keywords: ['glm', 'flash', 'eval', 'triage', 'budget', 'cheap', 'sale']),

  // ─── 70+ NVIDIA NIM Server Endpoints (Free Cloud Execution) ───────
  const SwarmModel(id: 'moonshotai/kimi-k3:free', name: 'Kimi K3 NIM (Free)', role: 'Frontend & Layout Agent', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '200K', description: 'Moonshot AI 2.8T MoE with Delta Attention on NVIDIA NIM free endpoint. Accelerated UI layout & frontend code generation.', keywords: ['nvidia', 'kimi', 'k3', 'moonshot', 'frontend', 'free']),
  const SwarmModel(id: 'nvidia/kimi-k3-nvfp4:free', name: 'Kimi K3 NVFP4 NIM (Free)', role: 'FP4 Accelerated Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '200K', description: 'NVIDIA TensorRT FP4 quantized Kimi K3 for maximum token throughput and lower latency.', keywords: ['nvidia', 'kimi', 'k3', 'nvfp4', 'free']),
  const SwarmModel(id: 'moonshotai/kimi-k2-instruct:free', name: 'Kimi K2 Instruct NIM (Free)', role: 'Agentic MoE Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Moonshot K2 open MoE for reasoning and multi-turn instruction following.', keywords: ['nvidia', 'kimi', 'k2', 'free']),
  const SwarmModel(id: 'deepseek-ai/deepseek-r1:free', name: 'DeepSeek R1 NIM (Free)', role: 'Open Reasoning Benchmark', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'DeepSeek R1 reasoning architecture hosted on NVIDIA HGX H100 GPU clusters.', keywords: ['nvidia', 'deepseek', 'r1', 'reasoning', 'free']),
  const SwarmModel(id: 'deepseek-ai/deepseek-v3:free', name: 'DeepSeek V3 NIM (Free)', role: 'Dense Coding Core', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: '671B parameter sparse MoE for code generation and multi-file reasoning.', keywords: ['nvidia', 'deepseek', 'v3', 'coding', 'free']),
  const SwarmModel(id: 'qwen/qwq-32b-preview:free', name: 'QwQ 32B Reasoning NIM (Free)', role: 'Analytical Reasoner', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '32K', description: 'Alibaba QwQ deep reasoning and mathematical proof generation model.', keywords: ['nvidia', 'qwen', 'qwq', 'math', 'free']),
  const SwarmModel(id: 'nvidia/llama-3.1-nemotron-70b-instruct:free', name: 'Nemotron Lightning 70B', role: 'Fast Reasoner', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Lightning fast reasoning and high-throughput dialogue.', keywords: ['nvidia', 'nemotron', 'lightning', 'free']),
  const SwarmModel(id: 'nvidia/nemotron-4-340b-instruct:free', name: 'Nemotron 4 340B', role: 'Enterprise Logic', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Massive-scale enterprise reasoning and synthetic data generation.', keywords: ['nvidia', 'nemotron', 'huge', 'enterprise']),
  const SwarmModel(id: 'nvidia/nemotron-4-340b-reward:free', name: 'Nemotron 4 340B Reward', role: 'Safety & Alignment', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'High-precision RLHF reward model for response grading.', keywords: ['nvidia', 'reward', 'alignment']),
  const SwarmModel(id: 'nvidia/llama-3.1-nemotron-51b-instruct:free', name: 'Nemotron 51B MoE', role: 'MoE Reasoner', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Sparse mixture of experts tuned for rapid instruction execution.', keywords: ['nvidia', 'moe', 'nemotron']),
  const SwarmModel(id: 'nvidia/nemotron-mini-4b-instruct:free', name: 'Nemotron Mini 4B', role: 'Edge Logic', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Ultra-lightweight embedded instruction model for local devices.', keywords: ['nvidia', 'edge', 'mini']),
  const SwarmModel(id: 'nvidia/llama3-chatqa-1.5-70b:free', name: 'Llama 3 ChatQA 70B', role: 'RAG Specialist', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'SOTA question answering over complex conversational tables and documents.', keywords: ['nvidia', 'rag', 'chatqa']),
  const SwarmModel(id: 'nvidia/llama3-chatqa-1.5-8b:free', name: 'Llama 3 ChatQA 8B', role: 'RAG Fast QA', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Compact RAG model optimized for tabular and unstructured context.', keywords: ['nvidia', 'rag', 'chatqa']),
  const SwarmModel(id: 'meta/llama-3.3-70b-instruct:free', name: 'Llama 3.3 70B NIM', role: 'Flagship Generalist', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'NVIDIA-accelerated Llama 3.3 flagship open weight model.', keywords: ['nvidia', 'llama3.3', 'flagship']),
  const SwarmModel(id: 'meta/llama-3.1-405b-instruct:free', name: 'Llama 3.1 405B NIM', role: 'Heavy Reasoner', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Full 405B parameter dense reasoning model on HGX H100 clusters.', keywords: ['nvidia', 'llama3.1', 'massive']),
  const SwarmModel(id: 'meta/llama-3.1-70b-instruct:free', name: 'Llama 3.1 70B NIM', role: 'Generalist Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'High quality coding and reasoning with FP8 TensorRT-LLM acceleration.', keywords: ['nvidia', 'llama3.1', 'fast']),
  const SwarmModel(id: 'meta/llama-3.1-8b-instruct:free', name: 'Llama 3.1 8B NIM', role: 'Edge Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Sub-millisecond token execution for fast interactive sessions.', keywords: ['nvidia', 'llama3.1', 'edge']),
  const SwarmModel(id: 'meta/llama-3.2-90b-vision-instruct:free', name: 'Llama 3.2 90B Vision NIM', role: 'Visual Reasoner', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Multimodal image and document comprehension at 90B scale.', keywords: ['nvidia', 'vision', 'multimodal']),
  const SwarmModel(id: 'meta/llama-3.2-11b-vision-instruct:free', name: 'Llama 3.2 11B Vision NIM', role: 'Visual Agent', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Fast multimodal image understanding and chart reading.', keywords: ['nvidia', 'vision', 'fast']),
  const SwarmModel(id: 'meta/llama-3.2-3b-instruct:free', name: 'Llama 3.2 3B NIM', role: 'Micro Reasoner', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Fast micro-scale model for edge reasoning.', keywords: ['nvidia', 'edge', 'micro']),
  const SwarmModel(id: 'meta/llama-3.2-1b-instruct:free', name: 'Llama 3.2 1B NIM', role: 'Embedded Core', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Smallest Llama 3.2 variant for high-throughput streaming.', keywords: ['nvidia', 'edge', 'embedded']),
  const SwarmModel(id: 'meta/codellama-70b:free', name: 'CodeLlama 70B NIM', role: 'Deep Syntax Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '100K', description: 'Deep code completion and syntax tree analysis.', keywords: ['nvidia', 'codellama', 'syntax']),
  const SwarmModel(id: 'mistralai/mistral-large-2-instruct:free', name: 'Mistral Large 2 NIM', role: 'European Flagship', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Flagship 123B model with multi-lingual and code mastery.', keywords: ['nvidia', 'mistral', 'flagship']),
  const SwarmModel(id: 'mistralai/mixtral-8x22b-instruct-v0.1:free', name: 'Mixtral 8x22B NIM', role: 'MoE Generalist', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '64K', description: 'High capacity mixture-of-experts for intricate logic and math.', keywords: ['nvidia', 'mixtral', 'moe']),
  const SwarmModel(id: 'mistralai/mixtral-8x7b-instruct-v0.1:free', name: 'Mixtral 8x7B NIM', role: 'MoE Fast Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '32K', description: 'Dense performance at sparse compute cost.', keywords: ['nvidia', 'mixtral', 'fast']),
  const SwarmModel(id: 'mistralai/mistral-nemo-12b-instruct:free', name: 'Mistral Nemo 12B NIM', role: 'Fast Conversational', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Trained jointly with NVIDIA for enterprise speed.', keywords: ['nvidia', 'nemo', 'fast']),
  const SwarmModel(id: 'mistralai/codestral-22b-instruct-v0.1:free', name: 'Codestral 22B NIM', role: 'Code Synthesis', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '32K', description: 'Dedicated code generation across 80+ programming languages.', keywords: ['nvidia', 'codestral', 'coding']),
  const SwarmModel(id: 'mistralai/mistral-7b-instruct-v0.3:free', name: 'Mistral 7B v0.3 NIM', role: 'General Agent', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '32K', description: 'Function calling and structured JSON output specialist.', keywords: ['nvidia', 'mistral', 'tools']),
  const SwarmModel(id: 'google/gemma-2-27b-it:free', name: 'Gemma 2 27B NIM', role: 'Dense Reasoner', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Outperforms older 70B models with sliding window attention.', keywords: ['nvidia', 'gemma', 'google']),
  const SwarmModel(id: 'google/gemma-2-9b-it:free', name: 'Gemma 2 9B NIM', role: 'High Throughput', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Best in class 9B parameter conversationalist.', keywords: ['nvidia', 'gemma', 'google']),
  const SwarmModel(id: 'google/gemma-2-2b-it:free', name: 'Gemma 2 2B NIM', role: 'Sub-Token Kernel', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Ultra lightweight Gemma architecture running on edge GPUs.', keywords: ['nvidia', 'gemma', 'light']),
  const SwarmModel(id: 'google/codegemma-7b:free', name: 'CodeGemma 7B NIM', role: 'Code Synthesis', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Google CodeGemma optimized for code infilling and AST generation.', keywords: ['nvidia', 'codegemma', 'coding']),
  const SwarmModel(id: 'microsoft/phi-3.5-moe-instruct:free', name: 'Phi-3.5 MoE NIM', role: 'MoE Dense Logic', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: '16x3.8B mixture-of-experts model for deep analytical tasks.', keywords: ['nvidia', 'phi', 'microsoft']),
  const SwarmModel(id: 'microsoft/phi-3.5-mini-instruct:free', name: 'Phi-3.5 Mini 128K NIM', role: 'Long Context Mini', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'High reasoning density with full 128K token retrieval.', keywords: ['nvidia', 'phi', 'context']),
  const SwarmModel(id: 'microsoft/phi-3.5-vision-instruct:free', name: 'Phi-3.5 Vision NIM', role: 'Vision & Chart Reader', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'High precision chart, diagram, and OCR extractor.', keywords: ['nvidia', 'vision', 'phi']),
  const SwarmModel(id: 'microsoft/phi-3-medium-4k-instruct:free', name: 'Phi-3 Medium NIM', role: 'Medium Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: '14B parameter powerhouse trained on textbook quality data.', keywords: ['nvidia', 'phi', 'medium']),
  const SwarmModel(id: 'microsoft/phi-3-mini-128k-instruct:free', name: 'Phi-3 Mini 128K NIM', role: 'Fast Infill', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: '3.8B parameter lightweight model with massive memory.', keywords: ['nvidia', 'phi', 'mini']),
  const SwarmModel(id: 'microsoft/phi-3-small-8k-instruct:free', name: 'Phi-3 Small 8K NIM', role: 'Small Dense Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: '7B model with tiktoken tokenizer for Python/C++ logic.', keywords: ['nvidia', 'phi', 'small']),
  const SwarmModel(id: 'snowflake/arctic-instruct:free', name: 'Snowflake Arctic NIM', role: 'Enterprise SQL', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Enterprise MoE tuned specifically for SQL query synthesis.', keywords: ['nvidia', 'snowflake', 'sql']),
  const SwarmModel(id: 'cohere/command-r-plus:free', name: 'Command R+ NIM', role: 'Multi-Step Orchestrator', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Enterprise RAG and multi-step tool use engine.', keywords: ['nvidia', 'cohere', 'tools']),
  const SwarmModel(id: 'cohere/command-r:free', name: 'Command R NIM', role: 'Tool Specialist', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'High speed retrieval and automated tool calling.', keywords: ['nvidia', 'cohere', 'rag']),
  const SwarmModel(id: 'databricks/dbrx-instruct:free', name: 'DBRX Instruct NIM', role: '132B Open MoE', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '32K', description: 'Databricks 16x12B architecture for coding and mathematics.', keywords: ['nvidia', 'databricks', 'moe']),
  const SwarmModel(id: 'bigcode/starcoder2-15b:free', name: 'StarCoder2 15B NIM', role: 'Code Engine', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '16K', description: 'Trained on Software Heritage data across 600+ languages.', keywords: ['nvidia', 'starcoder', 'coding']),
  const SwarmModel(id: 'bigcode/starcoder2-7b:free', name: 'StarCoder2 7B NIM', role: 'Fast Code Infill', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '16K', description: 'Optimized for fill-in-the-middle code auto-completion.', keywords: ['nvidia', 'starcoder', 'infill']),
  const SwarmModel(id: 'deepseek-ai/deepseek-coder-33b-instruct:free', name: 'DeepSeek Coder 33B NIM', role: 'Project Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '16K', description: 'Project-level code reasoning and git commit analysis.', keywords: ['nvidia', 'deepseek', 'coder']),
  const SwarmModel(id: 'deepseek-ai/deepseek-llm-67b-chat:free', name: 'DeepSeek LLM 67B NIM', role: 'Open LLM Core', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Comprehensive generalist knowledge model.', keywords: ['nvidia', 'deepseek', 'chat']),
  const SwarmModel(id: 'baichuan-inc/baichuan2-13b-chat:free', name: 'Baichuan 2 13B NIM', role: 'Bilingual Agent', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Trained on 2.6T tokens for Chinese and English fluency.', keywords: ['nvidia', 'baichuan', 'bilingual']),
  const SwarmModel(id: '01-ai/yi-large:free', name: 'Yi Large NIM', role: 'High End Reasoning', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '32K', description: 'Flagship 34B foundation model for reasoning benchmarks.', keywords: ['nvidia', 'yi', 'large']),
  const SwarmModel(id: 'qwen/qwen2.5-72b-instruct:free', name: 'Qwen 2.5 72B NIM', role: 'Flagship Open Weights', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Alibaba SOTA open weights model accelerated via TensorRT.', keywords: ['nvidia', 'qwen', 'flagship']),
  const SwarmModel(id: 'qwen/qwen2.5-coder-32b-instruct:free', name: 'Qwen 2.5 Coder 32B NIM', role: 'Coding Leader', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Top open-source coding model on HumanEval and SWE-bench.', keywords: ['nvidia', 'qwen', 'coder']),
  const SwarmModel(id: 'qwen/qwen2.5-14b-instruct:free', name: 'Qwen 2.5 14B NIM', role: 'Mid-tier Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Balanced speed and precision for routine programming tasks.', keywords: ['nvidia', 'qwen', 'mid']),
  const SwarmModel(id: 'qwen/qwen2.5-7b-instruct:free', name: 'Qwen 2.5 7B NIM', role: 'Low Latency Agent', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Fast reactive agent for micro-operations.', keywords: ['nvidia', 'qwen', 'fast']),
  const SwarmModel(id: 'nvidia/embeddings-nv-embed-qa-4:free', name: 'NV-Embed-QA 4', role: 'Vector Embedding', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '512', description: 'High dimensional vector representation for enterprise RAG.', keywords: ['nvidia', 'embedding', 'rag']),
  const SwarmModel(id: 'nvidia/reranking-nv-embed-rerank-large:free', name: 'NV Rerank Large', role: 'Reranking Engine', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '512', description: 'Second-stage cross-encoder reranker for vector search.', keywords: ['nvidia', 'rerank', 'rag']),
  const SwarmModel(id: 'nvidia/parakeet-ctc-1.1b:free', name: 'Parakeet CTC 1.1B', role: 'Speech Recognition', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: 'Stream', description: 'SOTA automated speech-to-text with English and accents.', keywords: ['nvidia', 'audio', 'parakeet']),
  const SwarmModel(id: 'nvidia/riva-tts-fastpitch:free', name: 'Riva FastPitch TTS', role: 'Voice Synthesis', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: 'Stream', description: 'Real-time expressive neural voice synthesizer.', keywords: ['nvidia', 'audio', 'tts']),
  const SwarmModel(id: 'upstage/solar-10.7b-instruct:free', name: 'Solar 10.7B NIM', role: 'Depth Upscaled Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Depth-upscaled architecture with dense mathematical logic.', keywords: ['nvidia', 'solar', 'upstage']),
  const SwarmModel(id: 'ibm/granite-34b-code-instruct:free', name: 'IBM Granite 34B Code NIM', role: 'Enterprise Mainframe Coder', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Enterprise code model trained on COBOL, Java, Python, and C.', keywords: ['nvidia', 'ibm', 'granite', 'code']),
  const SwarmModel(id: 'ibm/granite-20b-code-instruct:free', name: 'IBM Granite 20B Code NIM', role: 'Systems Code Specialist', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Automated code refactoring and memory safety analysis.', keywords: ['nvidia', 'ibm', 'granite']),
  const SwarmModel(id: 'ibm/granite-8b-code-instruct:free', name: 'IBM Granite 8B Code NIM', role: 'Rapid Refactorer', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Fast execution of unit test generation and linter fixes.', keywords: ['nvidia', 'ibm', 'granite', 'fast']),
  const SwarmModel(id: 'ibm/granite-3.0-8b-instruct:free', name: 'IBM Granite 3.0 8B NIM', role: 'Enterprise Assistant', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '128K', description: 'Third generation Granite model with instruction tuning.', keywords: ['nvidia', 'ibm', 'granite']),
  const SwarmModel(id: 'tiiuae/falcon-180b-chat:free', name: 'Falcon 180B NIM', role: 'Ultra Dense Cluster', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '2K', description: 'Trained on 3.5T tokens with multiquery attention.', keywords: ['nvidia', 'falcon', 'massive']),
  const SwarmModel(id: 'tiiuae/falcon-40b-instruct:free', name: 'Falcon 40B NIM', role: 'Architecture Model', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '2K', description: 'High efficiency dense parameters for systems blueprints.', keywords: ['nvidia', 'falcon', 'architecture']),
  const SwarmModel(id: 'allenai/olmo-7b-instruct:free', name: 'OLMo 7B NIM', role: 'Open Science Agent', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '2K', description: 'Fully open model and training data from AI2.', keywords: ['nvidia', 'olmo', 'open']),
  const SwarmModel(id: 'meditron/meditron-70b:free', name: 'Meditron 70B NIM', role: 'Bio & Medical Reasoner', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Clinical and biomedical literature reasoning engine.', keywords: ['nvidia', 'meditron', 'medical']),
  const SwarmModel(id: 'internlm/internlm2_5-20b-chat:free', name: 'InternLM 2.5 20B NIM', role: '1M Context Agent', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '1M', description: 'Ultra-long document retrieval and reasoning capability.', keywords: ['nvidia', 'internlm', 'context']),
  const SwarmModel(id: 'rwkv/rwkv-v5-eagle-7b:free', name: 'RWKV 5 Eagle NIM', role: 'RNN Linear Attention', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: 'Infinite', description: 'Infinite context linear attention RNN architecture.', keywords: ['nvidia', 'rwkv', 'rnn']),
  const SwarmModel(id: 'aisingapore/sea-lion-7b-instruct:free', name: 'SEA-LION 7B NIM', role: 'Multi-Lingual Edge', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Specialized in Southeast Asian languages and cultural context.', keywords: ['nvidia', 'sealion', 'regional']),
  const SwarmModel(id: 'writer/palmyra-med-70b:free', name: 'Palmyra Med 70B NIM', role: 'Clinical Diagnostic', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '32K', description: 'Tuned on clinical trial data and regulatory documents.', keywords: ['nvidia', 'palmyra', 'medical']),
  const SwarmModel(id: 'rakuten/rakutenai-7b-instruct:free', name: 'Rakuten AI 7B NIM', role: 'Asian Logic Agent', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Bilingual Japanese and English instruction specialist.', keywords: ['nvidia', 'rakuten', 'japan']),
  const SwarmModel(id: 'tokyotech-llm/llama-3-swallow-70b:free', name: 'Llama 3 Swallow 70B NIM', role: 'Swallow Cluster', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '8K', description: 'Enhanced vocabulary expansion and Japanese language synthesis.', keywords: ['nvidia', 'swallow', 'tokyo']),
  const SwarmModel(id: 'nvidia/cuopt-v1:free', name: 'NVIDIA cuOpt NIM', role: 'Combinatorial Solver', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: 'Solver', description: 'GPU-accelerated logistics and linear programming optimization.', keywords: ['nvidia', 'cuopt', 'solver']),
  const SwarmModel(id: 'nvidia/megatron-core-gpt-20b:free', name: 'Megatron Core 20B NIM', role: 'Parallel Transformer', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '4K', description: 'Benchmarked for maximum FLOPs utilization on NVIDIA chips.', keywords: ['nvidia', 'megatron', 'parallel']),
  const SwarmModel(id: 'nvidia/diffusers-sdxl-turbo:free', name: 'SDXL Turbo NIM', role: 'Image Synthesis', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '512x512', description: 'Single-step adversarial diffusion engine for instant image output.', keywords: ['nvidia', 'sdxl', 'diffusion']),
  const SwarmModel(id: 'nvidia/cosmos-nemotron-340b:free', name: 'Cosmos World Model NIM', role: 'Physical AI Simulator', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: 'Simulation', description: 'Physical AI physics and world dynamics simulator.', keywords: ['nvidia', 'cosmos', 'physics']),
  const SwarmModel(id: 'nvidia/omniverse-asset-reasoner-70b:free', name: 'Omniverse Reasoner 70B', role: 'USD Asset Compiler', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', contextWindow: '32K', description: 'Universal Scene Description parser and 3D pipeline manager.', keywords: ['nvidia', 'omniverse', 'usd']),

  // ─── OpenRouter AutoRouter & Video Generation Models ────────────
  const SwarmModel(id: 'openrouter/auto', name: 'OpenRouter Auto Router', role: 'Smart Task-Aware Router', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Dynamic Rate', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: 'Adaptive (up to 2M)', description: 'OpenRouter meta-model that automatically analyzes prompt intent, complexity, and capabilities to route requests to the optimal model dynamically.', keywords: ['auto', 'router', 'autorouter', 'openrouter', 'smart', 'dynamic', 'orchestrator']),
  const SwarmModel(id: 'x-ai/grok-imagine-video-1.5', name: 'Grok Imagine Video 1.5', role: 'Next-Gen Cinematic Video Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Async Video Generation', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1080p / 4K', description: 'xAI flagship generative video and dynamic physics model. Generates photorealistic cinematic video clips with rich physical coherence, fluid motion dynamics, and 4K upscaling.', keywords: ['video', 'x-ai', 'grok', 'grok-imagine', 'grok-video', 'cinematic', 'generation', 'default']),
  const SwarmModel(id: 'google/veo-3.1', name: 'Google Veo 3.1', role: 'Ultra-Fidelity 4K Video Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Async Video Generation', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1080p / 4K', description: 'Google flagship cinematic video generation model. Native synchronized audio, scene extensions up to 20 chained clips, and 4K upscaling.', keywords: ['video', 'google', 'veo', 'veo-3.1', 'cinematic', 'audio', 'generation']),
  const SwarmModel(id: 'google/veo-3.1-fast', name: 'Google Veo 3.1 Fast', role: 'High-Throughput Video Synthesis', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Async Video Generation', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '720p / 1080p', description: 'Optimized high-speed variant of Google Veo 3.1 for rapid previewing, turnaround generation, and real-time motion iteration.', keywords: ['video', 'google', 'veo', 'veo-fast', 'fast', 'generation']),
  const SwarmModel(id: 'openai/sora-2-pro', name: 'OpenAI Sora 2 Pro', role: 'Cinematic World & Physics Video', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Async Video Generation', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1080p / 20s', description: 'OpenAI flagship text-to-video and image-to-video generation model with deep physical simulation and temporal coherence.', keywords: ['video', 'openai', 'sora', 'sora-2', 'generation', 'physics']),
  const SwarmModel(id: 'kwaivgi/kling-v3.0-pro', name: 'Kling 3.0 Pro', role: 'High Motion Fidelity Video', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Async Video Generation', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1080p / 10s', description: 'Kuaishou Kling video generator with extraordinary biological and mechanical motion accuracy and 3D camera transitions.', keywords: ['video', 'kling', 'motion', 'generation', 'kwaivgi']),
  const SwarmModel(id: 'minimax/hailuo-2.3', name: 'MiniMax Hailuo 2.3', role: 'Cinematic Director Video', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Async Video Generation', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1080p / 6s', description: 'High-aesthetic cinematic video generation with dynamic camera movement, photorealistic textures, and lighting realism.', keywords: ['video', 'minimax', 'hailuo', 'generation', 'cinematic']),
  const SwarmModel(id: 'alibaba/wan-2.7', name: 'Alibaba Wan 2.7', role: 'Open Spatio-Temporal DiT Video', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Async Video Generation', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '720p / 1080p', description: 'Alibaba Wan open video generation model featuring advanced Spatio-Temporal DiT for fluid physical simulation and scene composition.', keywords: ['video', 'alibaba', 'wan', 'generation', 'dit']),
  const SwarmModel(id: 'bytedance/seedance-2.0', name: 'ByteDance Seedance 2.0', role: 'Dynamic Action & Dance Video', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: 'Async Video Generation', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '720p / 1080p', description: 'ByteDance video synthesis foundation model specializing in fluid character animation, sports choreography, and complex physical dynamics.', keywords: ['video', 'bytedance', 'seedance', 'generation', 'dance', 'action']),

  // ─── Daily Top 50 Coding & Reasoning Models (OpenRouter) ────────
  const SwarmModel(id: 'anthropic/claude-3.7-sonnet', name: 'Claude 3.7 Sonnet', role: 'Hybrid Reasoning Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$3.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'Anthropic flagship with selectable extended reasoning and elite coding.', keywords: ['claude', 'hybrid', 'coding', 'sota']),
  const SwarmModel(id: 'anthropic/claude-3.5-sonnet', name: 'Claude 3.5 Sonnet', role: 'Autonomous Software Dev', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$3.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'Industry-standard coding model for large repositories and AST diffs.', keywords: ['claude', 'coding', 'flagship']),
  const SwarmModel(id: 'openai/o1', name: 'OpenAI o1', role: 'Deep Logic & Proofs', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$15.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'Ultimate mathematical, system design, and competitive coding logic.', keywords: ['openai', 'reasoning', 'o1']),
  const SwarmModel(id: 'openai/o3-mini', name: 'OpenAI o3-mini', role: 'Rapid Reasoning Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$1.10 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'High-throughput chain-of-thought model for difficult programming tasks.', keywords: ['openai', 'reasoning', 'o3']),
  const SwarmModel(id: 'openai/o1-mini', name: 'OpenAI o1-mini', role: 'STEM Reasoning', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$3.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Fast reasoning model optimized for code debugging and math.', keywords: ['openai', 'math', 'code']),
  const SwarmModel(id: 'openai/gpt-4o', name: 'GPT-4o Flagship', role: 'Multimodal Systems Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$2.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Fast omni-model combining visual UI analysis with systems code.', keywords: ['openai', 'multimodal', 'fast']),
  const SwarmModel(id: 'openai/gpt-4o-mini', name: 'GPT-4o Mini', role: 'Budget Agentic Worker', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.12 / 1M', originalPricePer1M: r'$0.15 / 1M', isOnSale: true, saleDiscount: '20% OFF', contextWindow: '128K', description: 'High-speed lightweight agent for routine scripts and testing.', keywords: ['openai', 'budget', 'sale']),
  const SwarmModel(id: 'deepseek/deepseek-r1', name: 'DeepSeek R1', role: 'Open Reasoning Benchmark', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.55 / 1M', originalPricePer1M: r'$2.00 / 1M', isOnSale: true, saleDiscount: '72% OFF', contextWindow: '128K', description: '671B MoE model delivering o1-level performance at a fraction of the cost.', keywords: ['deepseek', 'reasoning', 'r1', 'sale']),
  const SwarmModel(id: 'deepseek/deepseek-chat', name: 'DeepSeek V3', role: 'Dense Coding Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.14 / 1M', originalPricePer1M: r'$0.28 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'Massive 671B MoE with unmatched cost-efficiency for programming.', keywords: ['deepseek', 'v3', 'coding', 'sale']),
  const SwarmModel(id: 'qwen/qwen-2.5-coder-32b-instruct', name: 'Qwen 2.5 Coder 32B', role: 'Open Source SOTA Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.18 / 1M', originalPricePer1M: r'$0.80 / 1M', isOnSale: true, saleDiscount: '75% OFF', contextWindow: '128K', description: 'Alibaba coding powerhouse matching major proprietary systems.', keywords: ['qwen', 'coder', 'sota', 'sale']),
  const SwarmModel(id: 'qwen/qwen-2.5-coder-72b-instruct', name: 'Qwen 2.5 Coder 72B', role: 'Heavy Architecture Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.70 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Large-scale code refactoring and multi-file codebases.', keywords: ['qwen', 'coder', 'heavy']),
  const SwarmModel(id: 'qwen/qwen-2.5-coder-7b-instruct', name: 'Qwen 2.5 Coder 7B', role: 'Sub-Second Infill', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.06 / 1M', originalPricePer1M: r'$0.10 / 1M', isOnSale: true, saleDiscount: '40% OFF', contextWindow: '32K', description: 'Blazing fast completion engine with near-zero latency.', keywords: ['qwen', 'coder', 'fast', 'sale']),
  const SwarmModel(id: 'qwen/qwen-2.5-72b-instruct', name: 'Qwen 2.5 72B', role: 'Full Stack Generalist', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.35 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'General intelligence flagship from Alibaba.', keywords: ['qwen', 'flagship']),
  const SwarmModel(id: 'qwen/qwen-max', name: 'Qwen Max', role: 'Proprietary Alibaba Peak', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$1.60 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Top-tier proprietary reasoning on Qwen cloud.', keywords: ['qwen', 'max']),
  const SwarmModel(id: 'zhipu/glm-4-plus', name: 'GLM-4 Plus', role: 'Bilingual Reasoning', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$1.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Zhipu AI flagship model with robust multi-step reasoning.', keywords: ['glm', 'zhipu', 'bilingual']),
  const SwarmModel(id: 'zhipu/glm-4-flash', name: 'GLM-4 Flash', role: 'Budget High Throughput', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.05 / 1M', originalPricePer1M: r'$0.10 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'High velocity model for automated agent workflows.', keywords: ['glm', 'flash', 'sale']),
  const SwarmModel(id: 'moonshotai/kimi-k2.5', name: 'Kimi K2.5', role: 'Agentic Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Moonshot AI high efficiency coding and instruction follower.', keywords: ['kimi', 'moonshot']),
  const SwarmModel(id: 'moonshotai/moonshot-v1-128k', name: 'Moonshot v1 128K', role: 'Long Document Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.80 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Deep memory for reading full repositories and specifications.', keywords: ['moonshot', 'context']),
  const SwarmModel(id: 'mistralai/codestral-2501', name: 'Codestral 2501', role: 'Code Synthesis Specialist', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.30 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '256K', description: 'Mistral SOTA code model trained on 80+ programming languages.', keywords: ['mistral', 'codestral', 'coding']),
  const SwarmModel(id: 'mistralai/mistral-large-2411', name: 'Mistral Large 2411', role: 'Enterprise Flagship', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$2.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Latest European flagship with reasoning on par with GPT-4o.', keywords: ['mistral', 'large']),
  const SwarmModel(id: 'mistralai/codestral-mamba', name: 'Codestral Mamba', role: 'State Space Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.25 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '256K', description: 'Linear-time inference for unlimited token generation.', keywords: ['mistral', 'mamba']),
  const SwarmModel(id: 'mistralai/ministral-8b', name: 'Ministral 8B', role: 'Fast Assistant', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.10 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Compact model with strong computer vision and code editing.', keywords: ['mistral', 'mini']),
  const SwarmModel(id: 'meta-llama/llama-3.3-70b-instruct', name: 'Llama 3.3 70B Turbo', role: 'Open Weight Flagship', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.35 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Meta flagship open model on high-speed OpenRouter endpoints.', keywords: ['meta', 'llama3.3']),
  const SwarmModel(id: 'meta-llama/llama-3.1-405b-instruct', name: 'Llama 3.1 405B', role: 'Massive Open Weights', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$2.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Largest open weights model for complex system design.', keywords: ['meta', 'llama3.1', '405b']),
  const SwarmModel(id: 'nousresearch/hermes-3-llama-3.1-405b', name: 'Nous Hermes 3 405B', role: 'Uncensored Flagship', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$2.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Unfiltered, steerable model for autonomous agent loops.', keywords: ['nous', 'hermes', 'uncensored']),
  const SwarmModel(id: 'google/gemini-2.5-pro', name: 'Gemini 2.5 Pro', role: '2M Ultra Context', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$1.25 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '2M', description: '2 Million token window capable of ingesting entire codebases.', keywords: ['google', 'gemini', 'context']),
  const SwarmModel(id: 'google/gemini-2.5-flash', name: 'Gemini 2.5 Flash', role: 'Ultra Fast Multimodal', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.075 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1M', description: 'Sub-200ms latency for real-time agentic actions.', keywords: ['google', 'gemini', 'flash']),
  const SwarmModel(id: 'google/gemini-flash-1.5-8b', name: 'Gemini Flash 1.5 8B', role: 'Micro Utility Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.037 / 1M', originalPricePer1M: r'$0.075 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '1M', description: 'Ultra low cost model for batch linting and verification.', keywords: ['google', 'gemini', 'budget', 'sale']),
  const SwarmModel(id: 'cohere/command-r-08-2024', name: 'Command R 08-2024', role: 'Tool Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.15 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Cohere updated model for automated JSON API calls.', keywords: ['cohere', 'tools']),
  const SwarmModel(id: 'cohere/command-r-plus-08-2024', name: 'Command R+ 08-2024', role: 'Enterprise Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$2.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Flagship multi-step planner and citation generator.', keywords: ['cohere', 'enterprise']),
  const SwarmModel(id: 'phind/phind-codellama-34b-v2', name: 'Phind CodeLlama 34B', role: 'Search & Code', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.20 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '16K', description: 'Technical search engine and code synthesizer.', keywords: ['phind', 'code']),
  const SwarmModel(id: '01-ai/yi-coder-9b', name: 'Yi-Coder 9B', role: 'Compact Code Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.08 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Dense coding performance in an agile 9B parameter package.', keywords: ['yi', 'coder']),
  const SwarmModel(id: 'deepseek/deepseek-coder-v2', name: 'DeepSeek Coder V2 236B', role: 'MoE Coding Pro', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.15 / 1M', originalPricePer1M: r'$0.30 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: '236B total parameters with 21B active per token.', keywords: ['deepseek', 'coder', 'sale']),
  const SwarmModel(id: 'bigcode/starcoder2-15b-instruct', name: 'StarCoder2 15B Instruct', role: 'Open Syntax Assistant', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.12 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '16K', description: 'Instruction-tuned on GitHub commits and technical docs.', keywords: ['starcoder', 'bigcode']),
  const SwarmModel(id: 'cognitivecomputations/dolphin3.0-r1-mistral-24b:free', name: 'Dolphin 3.0 R1 24B', role: 'Uncensored Reasoning', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Unfiltered reasoning model with no safety guardrails.', keywords: ['dolphin', 'uncensored', 'free']),
  const SwarmModel(id: 'huggingfaceh4/zephyr-7b-beta:free', name: 'Zephyr 7B', role: 'Conversational Free', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '4K', description: 'DPO tuned conversational model for direct assistance.', keywords: ['zephyr', 'free']),
  const SwarmModel(id: 'gryphe/mythomax-l2-13b', name: 'Mythomax 13B', role: 'Roleplay & Narrative', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.20 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Creative and expressive conversationalist for companion bots.', keywords: ['mythomax', 'roleplay']),
  const SwarmModel(id: 'sao10k/l3-euryale-v2.1-70b', name: 'Euryale 70B', role: 'Empathetic Confidant', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.70 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Deeply empathetic sounding board and therapist node.', keywords: ['euryale', 'therapist']),
  const SwarmModel(id: 'eva-unit-01/eva-qwen-2.5-72b', name: 'EVA Qwen 2.5 72B', role: 'Creative Assistant', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.80 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Fine-tuned Qwen 2.5 for complex multi-turn scenarios.', keywords: ['eva', 'qwen']),
  const SwarmModel(id: 'minimax/minimax-01', name: 'MiniMax-01 456B', role: 'Lightning Fast MoE', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.20 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '4M', description: 'High capacity MoE with 4M token context support.', keywords: ['minimax', 'moe']),
  const SwarmModel(id: 'ai21/jamba-1.5-large', name: 'Jamba 1.5 Large', role: 'Hybrid SSM Transformer', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$2.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '256K', description: 'Mamba and Transformer hybrid for long context tasks.', keywords: ['jamba', 'ai21']),
  const SwarmModel(id: 'ai21/jamba-1.5-mini', name: 'Jamba 1.5 Mini', role: 'Fast Hybrid Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.20 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '256K', description: 'Compact Mamba-Transformer for edge pipelines.', keywords: ['jamba', 'mini']),
  const SwarmModel(id: 'liquid/lfm-40b', name: 'Liquid LFM 40B', role: 'Liquid Neural Network', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'First-generation dynamic computational graph architecture.', keywords: ['liquid', 'lfm']),
  const SwarmModel(id: 'writer/palmyra-x-004', name: 'Palmyra X 004', role: 'Action & Tool Calling', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$2.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Enterprise autonomous agent model for workflows.', keywords: ['palmyra', 'enterprise']),
  const SwarmModel(id: 'anthropic/claude-3-5-haiku-4.5', name: 'Claude 3.5 Haiku', role: 'Ultra-Fast Verification', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.80 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'Lightning fast diagnostics and test matrix execution.', keywords: ['claude', 'haiku', 'qa']),
  const SwarmModel(id: 'anthropic/claude-3-opus', name: 'Claude 3.5 Opus', role: 'Deep Architectural Reasoning', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$15.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'Top-tier complex analysis and nuanced systems logic.', keywords: ['claude', 'opus', 'architecture']),
  const SwarmModel(id: 'deepseek/deepseek-math-7b', name: 'DeepSeek Math 7B', role: 'Algorithmic Solver', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.08 / 1M', originalPricePer1M: r'$0.15 / 1M', isOnSale: true, saleDiscount: '45% OFF', contextWindow: '16K', description: 'Specialized mathematical reasoning and algorithmic proofs.', keywords: ['deepseek', 'math', 'sale']),
  const SwarmModel(id: 'qwen2.5:7b', name: 'Qwen 2.5 7B (Local)', role: 'Local Generalist', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Local offline execution of Qwen 2.5 via Ollama.', keywords: ['local', 'ollama', 'generalist']),
  const SwarmModel(id: 'llama3.2:3b', name: 'Llama 3.2 3B (Local)', role: 'Local Edge Logic', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Ultra-lightweight local offline model via Ollama.', keywords: ['local', 'ollama', 'llama3.2']),

  // ─── Kimi Extended Family ─────────────────────────────────────────────────
  const SwarmModel(id: 'moonshotai/kimi-k1.5', name: 'Kimi K1.5', role: 'Long-Thinking Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.60 / 1M', originalPricePer1M: r'$1.20 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'Multi-modal long-chain-of-thought model trained with reinforcement learning. Rivals o1 on coding and AIME math.', keywords: ['kimi', 'k1.5', 'reasoning', 'moonshot', 'sale']),
  const SwarmModel(id: 'moonshotai/kimi-vl-a3b-thinking', name: 'Kimi VL A3B Thinking', role: 'Vision + Long Reasoning', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.15 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Lightweight multimodal MoE model with visual reasoning and chain-of-thought extended thinking for chart, diagram, and code analysis.', keywords: ['kimi', 'vl', 'vision', 'thinking', 'moonshot']),
  const SwarmModel(id: 'moonshotai/kimi-k2-instruct', name: 'Kimi K2 Instruct', role: 'Agentic MoE Planner', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.30 / 1M', originalPricePer1M: r'$0.60 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'Trillion-parameter MoE model designed for agentic loop tasks, long planning, and complex instruction following.', keywords: ['kimi', 'k2', 'moonshot', 'agentic', 'sale']),
  const SwarmModel(id: 'moonshotai/kimi-k3-thinking', name: 'Kimi K3 Thinking', role: 'Extended Reasoning Flagship', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'Kimi K3 with extended chain-of-thought reasoning mode enabled for hard problem solving, competitive coding, and architecture planning.', keywords: ['kimi', 'k3', 'thinking', 'reasoning', 'moonshot']),

  // ─── GLM Extended Family ──────────────────────────────────────────────────
  const SwarmModel(id: 'zhipu/glm-4-air', name: 'GLM-4 Air', role: 'Mid-Speed Bilingual Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.12 / 1M', originalPricePer1M: r'$0.25 / 1M', isOnSale: true, saleDiscount: '52% OFF', contextWindow: '128K', description: 'Efficient mid-tier GLM-4 variant for bilingual tasks, code review, and document summarization at low cost.', keywords: ['glm', 'air', 'bilingual', 'sale', 'zhipu']),
  const SwarmModel(id: 'zhipu/glm-4-long', name: 'GLM-4 Long', role: 'Long Context Document Reader', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.35 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1M', description: 'GLM-4 optimized for 1 million token document analysis, patent review, and full-repository code comprehension.', keywords: ['glm', 'long', 'context', 'zhipu']),
  const SwarmModel(id: 'zhipu/glm-4v-plus', name: 'GLM-4V Plus', role: 'Vision & UI Inspector', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.45 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Multimodal GLM-4 with high-res visual understanding for UI screenshot analysis, diagram reading, and OCR.', keywords: ['glm', 'vision', 'multimodal', 'zhipu']),
  const SwarmModel(id: 'zhipu/glm-z1-air', name: 'GLM-Z1 Air', role: 'Reasoning Mid-Tier', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.18 / 1M', originalPricePer1M: r'$0.36 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '32K', description: 'Zhipu Z1 reasoning model at Air efficiency tier — math, logic, and structured output at mid price.', keywords: ['glm', 'z1', 'reasoning', 'sale', 'zhipu']),
  const SwarmModel(id: 'zhipu/glm-z1-flash', name: 'GLM-Z1 Flash', role: 'Ultra-Cheap Reasoning Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.05 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Fastest and cheapest GLM reasoning variant for automated eval loops, CI checks, and lint triage.', keywords: ['glm', 'z1', 'flash', 'cheap', 'zhipu']),
  const SwarmModel(id: 'zhipu/glm-4-air-250414', name: 'GLM-4 Air (2504)', role: 'Latest Air Update', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.10 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'April 2025 updated GLM-4 Air with improved instruction following and code quality.', keywords: ['glm', 'air', 'zhipu', 'latest']),
  const SwarmModel(id: 'zhipu/glm-4-flashx', name: 'GLM-4 FlashX', role: 'Turbo Throughput Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.07 / 1M', originalPricePer1M: r'$0.14 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'eXtreme throughput GLM-4 Flash variant for maximum tokens-per-second in agentic pipelines.', keywords: ['glm', 'flashx', 'turbo', 'sale', 'zhipu']),

  // ─── Nemotron Extended Family ─────────────────────────────────────────────
  const SwarmModel(id: 'nvidia/nemotron-ultra-253b-v1', name: 'Nemotron Ultra 253B', role: 'NVIDIA Flagship Reasoner', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.80 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'NVIDIA open 253B parameter reasoning model built on Llama architecture, optimized with GRPO for code, math, and science.', keywords: ['nvidia', 'nemotron', 'ultra', '253b', 'reasoning']),
  const SwarmModel(id: 'nvidia/llama-3.1-nemotron-70b-instruct', name: 'Nemotron 70B Instruct', role: 'High Accuracy Reasoning', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.35 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'NVIDIA fine-tuned Llama 3.1 70B with reward model optimization for human preference alignment and RLHF.', keywords: ['nvidia', 'nemotron', '70b', 'rlhf']),
  const SwarmModel(id: 'nvidia/llama-3.3-nemotron-super-49b-v1', name: 'Nemotron Super 49B', role: 'MoE Efficiency Flagship', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.42 / 1M', originalPricePer1M: r'$0.60 / 1M', isOnSale: true, saleDiscount: '30% OFF', contextWindow: '128K', description: 'Nemotron Super 49B skyscraper MoE — near-Ultra quality at half the compute cost. Ideal mid-range pick for coding and tool use.', keywords: ['nvidia', 'nemotron', 'super', '49b', 'moe', 'sale']),
  const SwarmModel(id: 'nvidia/llama-3.3-nemotron-super-49b-v1:free', name: 'Nemotron Super 49B (Free)', role: 'Free MoE Reasoning', provider: ProviderId.nvidia, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Free NVIDIA NIM endpoint for Nemotron Super 49B — skyscraper MoE architecture for fast free inference.', keywords: ['nvidia', 'nemotron', 'super', 'free']),
  const SwarmModel(id: 'nvidia/nemotron-h-56b-base', name: 'Nemotron-H 56B Base', role: 'Hybrid Mamba SSM Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.40 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Hybrid Mamba / Transformer (H architecture) base model. Linear-time token generation, memory efficient, strong on long-context code.', keywords: ['nvidia', 'nemotron-h', 'mamba', 'hybrid', 'ssm']),

  // ─── DeepSeek Extended Family ─────────────────────────────────────────────
  const SwarmModel(id: 'deepseek/deepseek-r1-0528', name: 'DeepSeek R1 0528', role: 'Updated Reasoning Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.55 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'May 2025 DeepSeek R1 update with dramatically improved performance on coding and reasoning benchmarks.', keywords: ['deepseek', 'r1', 'reasoning', 'updated']),
  const SwarmModel(id: 'deepseek/deepseek-r1-0528:free', name: 'DeepSeek R1 0528 (Free)', role: 'Free Updated Reasoner', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Free OpenRouter access to the May 2528 DeepSeek R1 reasoning update.', keywords: ['deepseek', 'r1', 'free', 'updated']),
  const SwarmModel(id: 'deepseek/deepseek-r1-distill-qwen-32b', name: 'DeepSeek R1 Distill Qwen 32B', role: 'Distilled Reasoning Mid', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.18 / 1M', originalPricePer1M: r'$0.36 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'R1 reasoning capability distilled into a 32B Qwen backbone — mid-price sweet spot for reasoning and code tasks.', keywords: ['deepseek', 'r1', 'distill', 'qwen', 'mid', 'sale']),
  const SwarmModel(id: 'deepseek/deepseek-r1-distill-llama-70b', name: 'DeepSeek R1 Distill Llama 70B', role: 'Distilled Reasoning Heavy', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.35 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'R1 reasoning distilled into Llama 3.1 70B for deep logic, STEM, and competitive programming.', keywords: ['deepseek', 'r1', 'distill', 'llama', 'heavy']),
  const SwarmModel(id: 'deepseek/deepseek-r1-distill-qwen-14b', name: 'DeepSeek R1 Distill Qwen 14B', role: 'Compact Reasoning Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.08 / 1M', originalPricePer1M: r'$0.15 / 1M', isOnSale: true, saleDiscount: '47% OFF', contextWindow: '64K', description: 'Lightweight 14B distilled reasoning model — great mid-range pick for code review and bug analysis.', keywords: ['deepseek', 'r1', 'distill', 'compact', 'sale']),
  const SwarmModel(id: 'deepseek/deepseek-r1-distill-qwen-7b', name: 'DeepSeek R1 Distill Qwen 7B', role: 'Edge Reasoning Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.05 / 1M', originalPricePer1M: r'$0.10 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '32K', description: 'Smallest DeepSeek R1 distillation for near-zero cost reasoning on simple code and logic tasks.', keywords: ['deepseek', 'r1', 'edge', 'cheap', 'sale']),
  const SwarmModel(id: 'deepseek/deepseek-v3-0324', name: 'DeepSeek V3 0324', role: 'March 2025 V3 Update', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.14 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'March 2025 refreshed DeepSeek V3 with coding, agentic, and long-context improvements.', keywords: ['deepseek', 'v3', 'coding', 'updated']),
  const SwarmModel(id: 'deepseek/deepseek-prover-v2', name: 'DeepSeek Prover V2', role: 'Formal Math Proof Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'DeepSeek formal theorem prover — subgoal decomposition for Lean4 and Isabelle proof generation.', keywords: ['deepseek', 'prover', 'math', 'lean', 'formal']),

  // ─── Qwen Extended Family ─────────────────────────────────────────────────
  const SwarmModel(id: 'qwen/qwq-32b', name: 'QwQ 32B', role: 'Open Reasoning Powerhouse', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.18 / 1M', originalPricePer1M: r'$0.40 / 1M', isOnSale: true, saleDiscount: '55% OFF', contextWindow: '128K', description: 'Alibaba open reasoning model matching o1-mini on AIME and SWE-bench with deep chain-of-thought.', keywords: ['qwen', 'qwq', 'reasoning', 'mid', 'sale']),
  const SwarmModel(id: 'qwen/qwen3-235b-a22b', name: 'Qwen3 235B A22B', role: 'Qwen3 MoE Flagship', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.22 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Alibaba Qwen3 series flagship MoE model: 235B total params, 22B active. Thinking + non-thinking modes, top coding and reasoning scores.', keywords: ['qwen3', 'moe', 'flagship', 'thinking']),
  const SwarmModel(id: 'qwen/qwen3-235b-a22b:free', name: 'Qwen3 235B A22B (Free)', role: 'Free MoE Flagship', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Free access to Alibaba Qwen3 235B A22B MoE flagship. Thinking mode for deep reasoning, non-thinking for fast coding.', keywords: ['qwen3', 'free', 'moe', 'thinking']),
  const SwarmModel(id: 'qwen/qwen3-30b-a3b', name: 'Qwen3 30B A3B', role: 'Compact MoE Mid', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.10 / 1M', originalPricePer1M: r'$0.20 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'Qwen3 30B MoE with only 3B active parameters — extremely efficient mid-range model for coding and structured tasks.', keywords: ['qwen3', 'compact', 'moe', 'efficient', 'sale']),
  const SwarmModel(id: 'qwen/qwen3-30b-a3b:free', name: 'Qwen3 30B A3B (Free)', role: 'Free Compact MoE', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Free access to Qwen3 30B MoE — lightweight agentic coder with thinking mode.', keywords: ['qwen3', 'free', 'compact']),
  const SwarmModel(id: 'qwen/qwen3-32b', name: 'Qwen3 32B', role: 'Dense Thinking Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.18 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Dense 32B Qwen3 model with built-in thinking mode. Strong on code generation, math, and instruction following.', keywords: ['qwen3', 'dense', 'thinking', 'coder']),
  const SwarmModel(id: 'qwen/qwen3-14b', name: 'Qwen3 14B', role: 'Mid Thinking Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.10 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Compact 14B dense Qwen3 with thinking and non-thinking modes for balanced mid-tier tasks.', keywords: ['qwen3', 'mid', 'thinking']),
  const SwarmModel(id: 'qwen/qwen3-8b', name: 'Qwen3 8B', role: 'Edge Thinking Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.06 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Smallest dense Qwen3 with reasoning capacity. Best-in-class 8B model on coding benchmarks.', keywords: ['qwen3', 'edge', 'compact', 'cheap']),
  const SwarmModel(id: 'qwen/qwen3-8b:free', name: 'Qwen3 8B (Free)', role: 'Free Edge Reasoner', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Free access to Qwen3 8B — fast thinking model for code review and logic.', keywords: ['qwen3', 'free', 'edge']),
  const SwarmModel(id: 'qwen/qwen-2.5-vl-72b-instruct', name: 'Qwen 2.5 VL 72B', role: 'Flagship Visual Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.40 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Top-tier vision-language model for complex screenshot analysis, OCR, diagram parsing, and UI code generation.', keywords: ['qwen', 'vl', 'vision', 'flagship']),
  const SwarmModel(id: 'qwen/qwen-2.5-vl-32b-instruct', name: 'Qwen 2.5 VL 32B', role: 'Mid Vision Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.20 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: '32B multimodal vision model for UI mockup analysis and visual code generation at mid price.', keywords: ['qwen', 'vl', 'vision', 'mid']),
  const SwarmModel(id: 'qwen/qwq-32b:free', name: 'QwQ 32B (Free)', role: 'Free Open Reasoner', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Free access to QwQ 32B deep reasoning model — competitive coding and math at zero cost.', keywords: ['qwen', 'qwq', 'free', 'reasoning']),

  // ─── Additional Mid-Range & Specialist Models ─────────────────────────────
  const SwarmModel(id: 'anthropic/claude-sonnet-4-5', name: 'Claude Sonnet 4.5', role: 'Balanced Intelligence Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$3.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '200K', description: 'Latest Claude Sonnet 4.5 with balanced reasoning and coding at Sonnet price.', keywords: ['claude', 'sonnet', 'balanced']),
  const SwarmModel(id: 'google/gemini-2.0-pro-exp', name: 'Gemini 2.0 Pro Exp', role: 'Experimental Pro Multimodal', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.12 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '2M', description: 'Google Gemini 2.0 Pro experimental with 2M context for large codebase review and multimodal reasoning.', keywords: ['google', 'gemini', 'pro', 'experimental']),
  const SwarmModel(id: 'google/gemma-3-27b-it', name: 'Gemma 3 27B', role: 'Dense Open Weights Vision', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.14 / 1M', originalPricePer1M: r'$0.27 / 1M', isOnSale: true, saleDiscount: '48% OFF', contextWindow: '128K', description: 'Google Gemma 3 flagship open model with vision, long context, and function calling. SOTA on open benchmarks.', keywords: ['google', 'gemma', 'vision', 'open', 'sale']),
  const SwarmModel(id: 'google/gemma-3-12b-it', name: 'Gemma 3 12B', role: 'Mid Open Weights Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.06 / 1M', originalPricePer1M: r'$0.12 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '128K', description: 'Compact Gemma 3 12B with vision and instruction tuning at low cost.', keywords: ['google', 'gemma', 'compact', 'sale']),
  const SwarmModel(id: 'mistralai/mistral-small-24b', name: 'Mistral Small 24B', role: 'Efficient European Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.10 / 1M', originalPricePer1M: r'$0.20 / 1M', isOnSale: true, saleDiscount: '50% OFF', contextWindow: '32K', description: 'Mistral Small 24B instruction model with strong code quality and function calling at very low cost.', keywords: ['mistral', 'small', 'coding', 'sale']),
  const SwarmModel(id: 'mistralai/devstral-small', name: 'Devstral Small', role: 'Agentic Dev Specialist', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.10 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Mistral agentic model trained specifically for software engineering tasks — SWE-bench SOTA among open models.', keywords: ['mistral', 'devstral', 'swe', 'agentic']),
  const SwarmModel(id: 'meta-llama/llama-4-scout', name: 'Llama 4 Scout', role: 'Multimodal MoE Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.18 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '10M', description: 'Meta Llama 4 Scout — native multimodal 17Bx16E MoE with 10M context for extreme long-doc tasks.', keywords: ['meta', 'llama4', 'scout', 'multimodal', 'moe']),
  const SwarmModel(id: 'meta-llama/llama-4-maverick', name: 'Llama 4 Maverick', role: 'Maverick MoE Flagship', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.50 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1M', description: 'Meta Llama 4 Maverick — 17Bx128E MoE matching GPT-4o on benchmarks with 1M token context.', keywords: ['meta', 'llama4', 'maverick', 'moe', 'flagship']),
  const SwarmModel(id: 'x-ai/grok-3-mini-beta', name: 'Grok 3 Mini Beta', role: 'xAI Reasoning Mid', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.30 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '131K', description: 'xAI small reasoning model with chain-of-thought for math, coding, and STEM tasks at low cost.', keywords: ['xai', 'grok3', 'mini', 'reasoning']),
  const SwarmModel(id: 'x-ai/grok-3-beta', name: 'Grok 3 Beta', role: 'xAI Advanced Reasoning', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$3.00 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '131K', description: 'xAI flagship Grok 3 with deep reasoning for coding, science, and multi-step planning.', keywords: ['xai', 'grok3', 'flagship']),
  const SwarmModel(id: 'inflection/inflection-3-productivity', name: 'Inflection 3 Productivity', role: 'Enterprise Workflow Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.80 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Pi AI enterprise model tuned for workflow automation, document drafting, and structured output.', keywords: ['inflection', 'pi', 'enterprise', 'productivity']),
  const SwarmModel(id: 'amazon/nova-pro-v1', name: 'Amazon Nova Pro', role: 'AWS Multimodal Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.80 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '300K', description: 'Amazon flagship Nova Pro with vision, tool use, and 300K context for AWS-native pipelines.', keywords: ['amazon', 'nova', 'aws', 'multimodal']),
  const SwarmModel(id: 'amazon/nova-lite-v1', name: 'Amazon Nova Lite', role: 'AWS Budget Multimodal', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.06 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '300K', description: 'Ultra-low cost Amazon Nova multimodal model for batch processing and high-volume agent tasks.', keywords: ['amazon', 'nova', 'budget', 'cheap']),
  const SwarmModel(id: 'microsoft/phi-4-reasoning', name: 'Phi-4 Reasoning', role: 'Dense Reasoning Mid', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.07 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Microsoft Phi-4 reasoning-focused model — chain-of-thought math and coding at extremely low cost.', keywords: ['microsoft', 'phi4', 'reasoning', 'cheap']),
  const SwarmModel(id: 'microsoft/phi-4-reasoning-plus', name: 'Phi-4 Reasoning Plus', role: 'Enhanced Dense Reasoner', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.14 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Upgraded Phi-4 with extra RL training for harder math proofs, competitive coding, and rigorous logic.', keywords: ['microsoft', 'phi4', 'plus', 'reasoning']),

  // ─── Local Ollama Models (≤7B limit enforced) ──────────────────────────────
  // NOTE: Local models capped at 7B parameters for resource constraints.
  // Larger models (8B+) removed: deepseek-r1:8b/14b, gemma3:27b, qwq:32b,
  // llama4:scout (17Bx16E MoE), phi4:14b, qwen2.5-coder:32b.

  const SwarmModel(id: 'qwen2.5:7b', name: 'Qwen 2.5 7B (Local)', role: 'Local Generalist', provider: ProviderId.openrouter, tier: ModelTier.freeOnline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Local offline execution of Qwen 2.5 via Ollama.', keywords: ['local', 'ollama', 'generalist']),
  const SwarmModel(id: 'llama3.2:3b', name: 'Llama 3.2 3B (Local)', role: 'Local Edge Logic', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Ultra-lightweight local offline model via Ollama.', keywords: ['local', 'ollama', 'llama3.2']),

  // ─── Additional Local Models (≤7B) ─────────────────────────────────────────
  // Verified available on Ollama as of 2026-09-20. All ≤7B params.
  const SwarmModel(id: 'qwen2.5:3b', name: 'Qwen 2.5 3B (Local)', role: 'Compact Local Coder', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Qwen 2.5 3B — fast, capable small model for coding and reasoning.', keywords: ['local', 'ollama', 'qwen', 'compact']),
  const SwarmModel(id: 'qwen2.5:1.5b', name: 'Qwen 2.5 1.5B (Local)', role: 'Tiny Local Assistant', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Qwen 2.5 1.5B — ultra-fast tiny model for edge devices.', keywords: ['local', 'ollama', 'qwen', 'tiny']),
  const SwarmModel(id: 'qwen2.5-coder:7b', name: 'Qwen 2.5 Coder 7B (Local)', role: 'Local Code Specialist', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Qwen 2.5 Coder 7B — specialized for code generation and editing.', keywords: ['local', 'ollama', 'qwen', 'coder']),
  const SwarmModel(id: 'qwen2.5-coder:3b', name: 'Qwen 2.5 Coder 3B (Local)', role: 'Compact Code Model', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Qwen 2.5 Coder 3B — small but capable coding assistant.', keywords: ['local', 'ollama', 'qwen', 'coder', 'compact']),
  const SwarmModel(id: 'qwen2.5-coder:1.5b', name: 'Qwen 2.5 Coder 1.5B (Local)', role: 'Tiny Code Model', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '32K', description: 'Qwen 2.5 Coder 1.5B — minimal footprint code completion.', keywords: ['local', 'ollama', 'qwen', 'coder', 'tiny']),
  const SwarmModel(id: 'llama3.2:1b', name: 'Llama 3.2 1B (Local)', role: 'Micro Local Model', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Llama 3.2 1B — smallest Llama for ultra-constrained environments.', keywords: ['local', 'ollama', 'llama', 'micro']),
  const SwarmModel(id: 'gemma2:2b', name: 'Gemma 2 2B (Local)', role: 'Google Small Model', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Google Gemma 2 2B — efficient small model with strong benchmarks.', keywords: ['local', 'ollama', 'gemma', 'google']),
  const SwarmModel(id: 'gemma2:7b', name: 'Gemma 2 7B (Local)', role: 'Google Mid Model', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'Google Gemma 2 7B — best-in-class 7B open model.', keywords: ['local', 'ollama', 'gemma', 'google']),
  const SwarmModel(id: 'phi3:3.8b', name: 'Phi-3 Mini 3.8B (Local)', role: 'Microsoft Small Reasoner', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Microsoft Phi-3 Mini — strong reasoning in a small package.', keywords: ['local', 'ollama', 'phi3', 'microsoft']),
  const SwarmModel(id: 'phi3.5:3.8b', name: 'Phi-3.5 Mini 3.8B (Local)', role: 'Updated Phi Mini', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'Microsoft Phi-3.5 Mini — improved instruction following and multilingual.', keywords: ['local', 'ollama', 'phi3', 'microsoft']),
  const SwarmModel(id: 'smollm2:1.7b', name: 'SmolLM2 1.7B (Local)', role: 'HuggingFace Tiny', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'HuggingFace SmolLM2 1.7B — state-of-the-art tiny model.', keywords: ['local', 'ollama', 'smollm', 'huggingface']),
  const SwarmModel(id: 'smollm2:360m', name: 'SmolLM2 360M (Local)', role: 'Micro SmolLM', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '8K', description: 'HuggingFace SmolLM2 360M — smallest usable instruct model.', keywords: ['local', 'ollama', 'smollm', 'micro']),
  const SwarmModel(id: 'tinyllama:1.1b', name: 'TinyLlama 1.1B (Local)', role: 'Ultra-Tiny Model', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '2K', description: 'TinyLlama 1.1B — 1.1B params, 2K context, runs anywhere.', keywords: ['local', 'ollama', 'tinyllama', 'micro']),
  const SwarmModel(id: 'stablelm2:1.6b', name: 'StableLM2 1.6B (Local)', role: 'Stability AI Small', provider: ProviderId.ollama, tier: ModelTier.offline, pricePer1M: 'FREE', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '4K', description: 'Stability AI StableLM2 1.6B — multilingual small model.', keywords: ['local', 'ollama', 'stablelm', 'stability']),

  // ─── New default swarm members (2026-09-19) — verified against OpenRouter's
  // live /api/v1/models + real pricing at write time, not estimated. Two notes:
  // the requested "GLM 5.6" doesn't exist on OpenRouter (their GLM line tops
  // out at 5.3 right now) so this substitutes the current real flagship; and
  // OpenRouter's Zhipu/GLM provider slug is 'z-ai/', not the 'zhipu/' prefix
  // the rest of this catalog uses for GLM entries below — those older entries
  // were never re-verified and are likely stale, out of scope for this pass.
  const SwarmModel(id: 'moonshotai/kimi-k2.6', name: 'Kimi K2.6', role: 'General Coding Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.95 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '256K', description: 'MoonshotAI\'s current agentic coding model — long-context multi-file work and tool use.', keywords: ['kimi', 'moonshot', 'coding', 'default']),
  const SwarmModel(id: 'z-ai/glm-5.3', name: 'GLM 5.3', role: 'General Coding Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.91 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1.3M', description: 'Zhipu/Z.ai\'s current flagship — substituted for the requested "GLM 5.6", which does not exist on OpenRouter; 5.3 is the real current top of that line.', keywords: ['glm', 'zhipu', 'z-ai', 'coding', 'default']),
  const SwarmModel(id: 'nvidia/nemotron-3-ultra-550b-a55b', name: 'Nemotron 3 Ultra', role: 'System, Eval & Gaming Reasoner', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.60 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '256K', description: 'NVIDIA\'s current flagship Nemotron — the default for system-utility agents, Dr. Boltz, and gaming-tagged agents; separate from GamingAgent\'s own direct-NVIDIA-API Lucille eval pipeline, which is unaffected by this swarm.', keywords: ['nvidia', 'nemotron', 'system', 'eval', 'gaming', 'default']),

  // ─── Cost-Efficient Top Tier (2026-09-21) — the "top swarm" members.
  // All verified live on OpenRouter at write time with real per-token prices.
  // These are the current-generation flagships that still price under $2/1M
  // blended — the sweet spot the user asked for: top-tier quality without
  // the $5-15/1M Opus/GPT-5-Pro pricing.
  const SwarmModel(id: 'qwen/qwen3.6-plus', name: 'Qwen 3.6 Plus', role: 'Top-Tier General Coding Agent', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.33 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '256K', description: 'Alibaba\'s Qwen 3.6 Plus — flagship-tier reasoning and coding at a fraction of Western flagship pricing. The sweet spot of the Qwen 3.6 line.', keywords: ['qwen', '3.6', 'plus', 'coding', 'top', 'default']),
  const SwarmModel(id: 'z-ai/glm-5.3-flash', name: 'GLM 5.3 Flash', role: 'High-Speed Top-Tier Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.09 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1M', description: 'Z.ai\'s GLM 5.3 Flash — near-flagship quality at 1/10th flagship price with a 1M context window. The cost-efficiency king of the GLM 5.3 line.', keywords: ['glm', 'flash', 'z-ai', 'coding', 'top', 'cheap', 'default']),
  const SwarmModel(id: 'deepseek/deepseek-v4-pro', name: 'DeepSeek V4 Pro', role: 'Deep Reasoning & Heavy Coding', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.95 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'DeepSeek\'s V4 Pro — o1-class reasoning and multi-file coding at open-weight pricing. The strongest DeepSeek for hard problems.', keywords: ['deepseek', 'v4', 'pro', 'reasoning', 'coding', 'top', 'default']),
  const SwarmModel(id: 'deepseek/deepseek-v4-flash', name: 'DeepSeek V4 Flash', role: 'Ultra-Cheap High-Quality Coder', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.06 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '128K', description: 'DeepSeek V4 Flash — the cheapest model in the top tier. Near-V4-Pro quality for routine coding at pennies per million tokens.', keywords: ['deepseek', 'v4', 'flash', 'coding', 'top', 'cheap', 'default']),
  const SwarmModel(id: 'z-ai/glm-5.3-flashx', name: 'GLM 5.3 FlashX', role: 'Turbo Throughput Engine', provider: ProviderId.openrouter, tier: ModelTier.paidOnline, pricePer1M: r'$0.37 / 1M', originalPricePer1M: null, isOnSale: false, saleDiscount: null, contextWindow: '1M', description: 'The throughput variant of GLM 5.3 Flash — maximum tokens-per-second for agentic pipelines that need speed over depth.', keywords: ['glm', 'flashx', 'z-ai', 'turbo', 'top']),

];

/// Pre-configured System Swarms
final swarms = <String, SwarmConfig>{
  // ─── NEW DEFAULT FLAGSHIP SWARM (For Everyone) ──────────────────────────
  // 2026-09-21: rebuilt as the cost-efficient TOP swarm. Every member is a
  // current-generation flagship that blends under ~$0.50/1M — top-tier
  // quality without the $5-15/1M Opus/GPT-5-Pro tier. Anything pricier is
  // a deliberate opt-in (heavy-cloud-council) rather than the default.
  'default-coding-swarm': SwarmConfig(
    id: 'default-coding-swarm',
    name: 'Top Swarm (Cost-Efficient Flagships)',
    role: 'Everyday Coding & Chat — Everyone Except System/Gaming/Eval Agents',
    isDefault: true,
    estimatedPrice: r'~$0.45 / 1M (Blended Execution)',
    description: 'The top swarm: Kimi K2.6, Qwen 3.6 Plus, GLM 5.3 Flash, and DeepSeek V4 Pro/Flash — current-generation flagships, all under \$1/1M. Highest models by default; pick heavy-cloud-council only when you deliberately want the \$5+/1M tier.',
    models: [
      allModels.firstWhere((m) => m.id == 'moonshotai/kimi-k2.6'),
      allModels.firstWhere((m) => m.id == 'qwen/qwen3.6-plus'),
      allModels.firstWhere((m) => m.id == 'z-ai/glm-5.3-flash'),
      allModels.firstWhere((m) => m.id == 'deepseek/deepseek-v4-pro'),
      allModels.firstWhere((m) => m.id == 'deepseek/deepseek-v4-flash'),
    ],
  ),

  // ─── Nemotron-only swarm for gaming, system-utility, and eval agents ─────
  'nemotron-swarm': SwarmConfig(
    id: 'nemotron-swarm',
    name: 'Nemotron Swarm',
    role: 'System, Gaming & Eval Default',
    estimatedPrice: r'~$0.60 / 1M',
    description: 'NVIDIA Nemotron 3 Ultra only — default for system-utility agents (Archivist, Sonar, Weaver, Oracle, Warden, Scribe, Chronos, Voyager, Spectre, Pulse, Echo, Maestro, Scout, Titan), Dr. Boltz, and the gaming-tagged agents (Nexus, Librarian, Streamer). Distinct from GamingAgent-go\'s own direct-NVIDIA-API Lucille eval, which never goes through this OpenRouter-based swarm system at all.',
    models: [
      allModels.firstWhere((m) => m.id == 'nvidia/nemotron-3-ultra-550b-a55b'),
    ],
  ),

  // ─── OpenRouter AutoRouter Swarm ─────────────────────────────────────────
  'autorouter-swarm': SwarmConfig(
    id: 'autorouter-swarm',
    name: 'OpenRouter AutoRouter (Dynamic)',
    role: 'Dynamic Task-Aware Intelligent Dispatch',
    description: 'Auto-routes every prompt to the optimal model based on prompt complexity, task requirements, context size, and price/performance trade-offs.',
    models: [
      allModels.firstWhere((m) => m.id == 'openrouter/auto'),
    ],
    estimatedPrice: 'Dynamic Market Rate',
  ),

  // ─── Cinematic Video Generation Suite ─────────────────────────────────────
  'video-generation-swarm': SwarmConfig(
    id: 'video-generation-swarm',
    name: 'Cinematic Video Generation Suite',
    role: 'Text-to-Video & Image-to-Video Production',
    description: 'Complete high-fidelity video production suite: xAI Grok Imagine Video 1.5, Google Veo 3.1, OpenAI Sora 2 Pro, Kling 3.0 Pro, and Alibaba Wan 2.7 for photorealistic video generation.',
    models: [
      allModels.firstWhere((m) => m.id == 'x-ai/grok-imagine-video-1.5'),
      allModels.firstWhere((m) => m.id == 'google/veo-3.1'),
      allModels.firstWhere((m) => m.id == 'openai/sora-2-pro'),
      allModels.firstWhere((m) => m.id == 'kwaivgi/kling-v3.0-pro'),
      allModels.firstWhere((m) => m.id == 'alibaba/wan-2.7'),
    ],
    estimatedPrice: 'Async Video Rates (OpenRouter)',
  ),

  // ─── NVIDIA Free Power Mesh (100% Free NIM GPU Endpoints) ─────────────────
  'nim-free-power-swarm': SwarmConfig(
    id: 'nim-free-power-swarm',
    name: 'NVIDIA Free Power Mesh',
    role: '100% Free NIM GPU Endpoints',
    description: '100% free high-throughput GPU cluster powered by NVIDIA NIM endpoints: Kimi K3 Free, DeepSeek R1 Free, Nemotron 70B, and Llama 3.3 70B with auto-failover.',
    models: [
      allModels.firstWhere((m) => m.id == 'moonshotai/kimi-k3:free'),
      allModels.firstWhere((m) => m.id == 'deepseek-ai/deepseek-r1:free'),
      allModels.firstWhere((m) => m.id == 'nvidia/llama-3.1-nemotron-70b-instruct:free'),
      allModels.firstWhere((m) => m.id == 'meta/llama-3.3-70b-instruct:free'),
      allModels.firstWhere((m) => m.id == 'qwen/qwq-32b-preview:free'),
    ],
    estimatedPrice: 'FREE',
  ),

  // ─── High-Efficiency Budget UI & Coding/Eval Swarms ───────────────────────
  'budget-ui-studio-swarm': SwarmConfig(
    id: 'budget-ui-studio-swarm',
    name: 'Budget UI & Layout Studio Swarm',
    role: 'Cost-Effective Reactive UI & Component Design',
    description: 'High-speed, budget-friendly UI development suite: Gemini 2.0 Flash Lite for wireframing, Kimi K3 NIM (Free) for reactive layouts, and Qwen 2.5 VL for visual component inspection.',
    models: [
      allModels.firstWhere((m) => m.id == 'google/gemini-2.0-flash-lite'),
      allModels.firstWhere((m) => m.id == 'moonshotai/kimi-k3:free'),
      allModels.firstWhere((m) => m.id == 'qwen/qwen-2.5-vl-7b-instruct'),
    ],
    estimatedPrice: r'~$0.08 / 1M (Ultra Low Cost)',
  ),

  'budget-coding-eval-swarm': SwarmConfig(
    id: 'budget-coding-eval-swarm',
    name: 'Budget Code & Automated Eval Swarm',
    role: 'Cost-Effective Code Generation, Diff Verification & Eval',
    description: 'High-efficiency programming and evaluation cluster: DeepSeek V3 for multi-file AST patching, Qwen 2.5 Coder 32B for syntax generation, and GLM-4 Flash for compiler test matrices.',
    models: [
      allModels.firstWhere((m) => m.id == 'deepseek/deepseek-chat'),
      allModels.firstWhere((m) => m.id == 'qwen/qwen-2.5-coder-32b-instruct'),
      allModels.firstWhere((m) => m.id == 'zhipu/glm-4-flash'),
      allModels.firstWhere((m) => m.id == 'nvidia/llama-3.1-nemotron-70b-instruct:free'),
    ],
    estimatedPrice: r'~$0.10 / 1M (Ultra Low Cost)',
  ),

  // ─── Alternative Standard Swarms ──────────────────────────────────────
  'free-uncensored': SwarmConfig(
    id: 'free-uncensored',
    name: 'Free Uncensored Swarm',
    role: 'Unfiltered Free Advice & Chat',
    models: [
      allModels.firstWhere((m) => m.id == 'cognitivecomputations/dolphin3.0-r1-mistral-24b:free'),
      allModels.firstWhere((m) => m.id == 'huggingfaceh4/zephyr-7b-beta:free'),
    ],
    estimatedPrice: 'FREE',
  ),

  'cloud-uncensored': SwarmConfig(
    id: 'cloud-uncensored',
    name: 'Pro Uncensored Swarm',
    role: 'Unfiltered Pro Advice & Systems',
    models: [
      allModels.firstWhere((m) => m.id == 'gryphe/mythomax-l2-13b'),
      allModels.firstWhere((m) => m.id == 'sao10k/l3-euryale-v2.1-70b'),
      allModels.firstWhere((m) => m.id == 'nousresearch/hermes-3-llama-3.1-405b'),
    ],
    estimatedPrice: r'~$0.90 / 1M',
  ),

  'therapist-swarm': SwarmConfig(
    id: 'therapist-swarm',
    name: 'Therapist & Confidant Swarm',
    role: 'Empathetic Sounding Board',
    models: [
      allModels.firstWhere((m) => m.id == 'sao10k/l3-euryale-v2.1-70b'),
      allModels.firstWhere((m) => m.id == 'cognitivecomputations/dolphin3.0-r1-mistral-24b:free'),
    ],
    estimatedPrice: r'~$0.40 / 1M',
  ),

  'free-local-iron': SwarmConfig(
    id: 'free-local-iron',
    name: 'Offline Local Iron Swarm',
    role: 'Air-Gapped Private Execution (≤7B)',
    models: [
      allModels.firstWhere((m) => m.id == 'qwen2.5:7b'),
      allModels.firstWhere((m) => m.id == 'llama3.2:3b'),
    ],
    estimatedPrice: 'FREE',
  ),

  'nvidia-free-cloud': SwarmConfig(
    id: 'nvidia-free-cloud',
    name: 'NVIDIA 70-NIM Accelerated Swarm',
    role: 'High-Throughput Free GPU Endpoints',
    models: [
      allModels.firstWhere((m) => m.id == 'nvidia/llama-3.1-nemotron-70b-instruct:free'),
      allModels.firstWhere((m) => m.id == 'nvidia/nemotron-4-340b-instruct:free'),
      allModels.firstWhere((m) => m.id == 'meta/llama-3.3-70b-instruct:free'),
      allModels.firstWhere((m) => m.id == 'mistralai/codestral-22b-instruct-v0.1:free'),
      allModels.firstWhere((m) => m.id == 'nvidia/llama3-chatqa-1.5-70b:free'),
    ],
    estimatedPrice: 'FREE',
  ),

  'heavy-cloud-council': SwarmConfig(
    id: 'heavy-cloud-council',
    name: 'Heavy Cloud Council',
    role: 'Maximum Capability High-Budget Reasoning',
    models: [
      allModels.firstWhere((m) => m.id == 'openai/o1'),
      allModels.firstWhere((m) => m.id == 'anthropic/claude-3.7-sonnet'),
      allModels.firstWhere((m) => m.id == 'deepseek/deepseek-r1'),
      allModels.firstWhere((m) => m.id == 'meta-llama/llama-3.1-405b-instruct'),
    ],
    estimatedPrice: r'~$5.50 / 1M',
  ),
};

SwarmConfig getSwarm(String id) => swarms[id] ?? swarms['default-coding-swarm']!;

// ─── Custom Swarms Persistence ─────────────────────────────────────────────

const String _kCustomSwarmsKey = 'SWARM_CUSTOM_CONFIGS_V1';

Future<List<SwarmConfig>> loadCustomSwarms() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCustomSwarmsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) => SwarmConfig.fromJson(item as Map<String, dynamic>)).toList();
  } catch (e) {
    return [];
  }
}

Future<void> saveCustomSwarm(SwarmConfig config) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadCustomSwarms();
    existing.removeWhere((s) => s.id == config.id);
    existing.add(config);
    final raw = jsonEncode(existing.map((s) => s.toJson()).toList());
    await prefs.setString(_kCustomSwarmsKey, raw);
  } catch (e) {
    // ignore
  }
}

Future<void> deleteCustomSwarm(String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadCustomSwarms();
    existing.removeWhere((s) => s.id == id);
    final raw = jsonEncode(existing.map((s) => s.toJson()).toList());
    await prefs.setString(_kCustomSwarmsKey, raw);
  } catch (e) {
    // ignore
  }
}
