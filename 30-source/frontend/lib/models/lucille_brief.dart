// Data models for Lucille Assistant's Team Brief + comment threads API
// (GET /api/artifact, POST /api/threads/post, POST /api/threads/ask).
// Mirrors the Go structs in threads.go / jobs.go on the Lucille Assistant
// service (source: /mnt/lucilleassistant).

class Statement {
  final String anchor;
  final String text;
  final String sub;
  final String tag;
  final String level; // ok | warn | bad | info
  final String status;
  final String due;

  Statement({
    required this.anchor,
    required this.text,
    this.sub = '',
    this.tag = '',
    this.level = '',
    this.status = '',
    this.due = '',
  });

  factory Statement.fromJson(Map<String, dynamic> j) => Statement(
        anchor: j['anchor'] ?? '',
        text: j['text'] ?? '',
        sub: j['sub'] ?? '',
        tag: j['tag'] ?? '',
        level: j['level'] ?? '',
        status: j['status'] ?? '',
        due: j['due'] ?? '',
      );
}

class BriefSection {
  final String id;
  final String title;
  final String note;
  final List<Statement> items;

  BriefSection({required this.id, required this.title, this.note = '', this.items = const []});

  factory BriefSection.fromJson(Map<String, dynamic> j) => BriefSection(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        note: j['note'] ?? '',
        items: ((j['items'] as List?) ?? [])
            .map((e) => Statement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ThreadMsg {
  final String id;
  final String anchor;
  final String at;
  final String by; // you | <phone label> | lucille | boltz | claude
  final String text;
  final String quote;
  final String model;
  final bool err;
  final String kind; // "coder" | "job" | ""

  ThreadMsg({
    required this.id,
    required this.anchor,
    required this.at,
    required this.by,
    required this.text,
    this.quote = '',
    this.model = '',
    this.err = false,
    this.kind = '',
  });

  factory ThreadMsg.fromJson(Map<String, dynamic> j) => ThreadMsg(
        id: j['id'] ?? '',
        anchor: j['anchor'] ?? '',
        at: j['at'] ?? '',
        by: j['by'] ?? '',
        text: j['text'] ?? '',
        quote: j['quote'] ?? '',
        model: j['model'] ?? '',
        err: j['err'] ?? false,
        kind: j['kind'] ?? '',
      );

  String get displayName {
    switch (by) {
      case 'lucille':
        return 'Lucille';
      case 'boltz':
        return 'Dr. Boltz';
      case 'claude':
        return 'Claude';
      case 'you':
        return 'You';
      default:
        return by;
    }
  }
}

class CoderJob {
  final String id;
  final String to;
  final String anchor;
  final String quote;
  final String prompt;
  final String status; // queued | claimed | done | manual | cancelled
  final String at;
  final String by;
  final String claimedBy;
  final String result;

  CoderJob({
    required this.id,
    required this.to,
    required this.anchor,
    required this.prompt,
    required this.status,
    this.quote = '',
    this.at = '',
    this.by = '',
    this.claimedBy = '',
    this.result = '',
  });

  factory CoderJob.fromJson(Map<String, dynamic> j) => CoderJob(
        id: j['id'] ?? '',
        to: j['to'] ?? '',
        anchor: j['anchor'] ?? '',
        quote: j['quote'] ?? '',
        prompt: j['prompt'] ?? '',
        status: j['status'] ?? '',
        at: j['at'] ?? '',
        by: j['by'] ?? '',
        claimedBy: j['claimed_by'] ?? '',
        result: j['result'] ?? '',
      );
}

class TeamBrief {
  final List<BriefSection> sections;
  final Map<String, List<ThreadMsg>> threads;
  final Map<String, List<CoderJob>> jobs;
  final int seq;

  TeamBrief({
    required this.sections,
    required this.threads,
    required this.jobs,
    required this.seq,
  });

  factory TeamBrief.fromJson(Map<String, dynamic> j) {
    final threads = <String, List<ThreadMsg>>{};
    (j['threads'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      threads[k] = (v as List).map((e) => ThreadMsg.fromJson(e as Map<String, dynamic>)).toList();
    });
    final jobs = <String, List<CoderJob>>{};
    (j['jobs'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      jobs[k] = (v as List).map((e) => CoderJob.fromJson(e as Map<String, dynamic>)).toList();
    });
    return TeamBrief(
      sections: ((j['sections'] as List?) ?? [])
          .map((e) => BriefSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      threads: threads,
      jobs: jobs,
      seq: (j['seq'] as num?)?.toInt() ?? 0,
    );
  }

  factory TeamBrief.empty() => TeamBrief(sections: const [], threads: const {}, jobs: const {}, seq: 0);
}
