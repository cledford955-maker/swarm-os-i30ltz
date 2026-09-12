# Remaining Tasks to Port Lucy Server to C#

Based on an analysis of the legacy Python codebase (`old_lucy_server_copy.py` and `old_swarm_google_api.py`), the following components, features, and API endpoints still need to be ported to the new C# `.NET` `LucyServer`.

---

## 1. System & Terminal Integration
APIs for interacting with the host operating system, managing packages, and running terminal commands.
- [ ] `POST /api/terminal/run` - Interactive terminal execution
- [ ] `POST /api/run_command` - Simple command execution
- [ ] `GET /api/system/processes` - List system processes
- [ ] `POST /api/system/process/kill` - Kill a specific process
- [ ] `GET /api/system/stats` - CPU, RAM, and system resource statistics
- [ ] `GET /api/packages/list` - List installed packages
- [ ] `POST /api/packages/uninstall` - Uninstall packages

## 2. File System & Code Editing
APIs for navigating the local file system, reading/writing files, and applying code upgrades.
- [ ] `GET /api/fs` - List directory contents
- [ ] `POST /api/fs/analyze` - Analyze directory structure
- [ ] `GET /api/code/files` - List code files in a project
- [ ] `POST /api/code/read` - Read file contents
- [ ] `POST /api/code/save` - Save changes to a file
- [ ] `POST /api/code/apply_upgrade` - Apply automated code upgrades/diffs
- [ ] `POST /api/recovery/mount` - Mount file systems/recovery modes

## 3. Chat History & Session Management
APIs for managing persistent chat sessions, renaming chats, and organizing them.
- [ ] `GET /api/chats` - List all chat sessions
- [ ] `POST /api/chats/new` - Create a new chat session
- [ ] `POST /api/chats/delete` - Delete a chat session
- [ ] `POST /api/chats/rename` - Rename a chat session
- [ ] `POST /api/chats/select` - Load a specific chat session
- [ ] `POST /api/chats/toggle_pin` - Pin/unpin a chat
- [ ] `POST /api/chats/toggle_privacy` - Toggle privacy mode for a chat

## 4. Local Model Management (Ollama)
APIs for pulling new models locally and checking download status.
- [ ] `GET /api/local_models` - List installed local models
- [ ] `POST /api/pull_model` - Initiate a model pull request to Ollama
- [ ] `GET /api/pull_status` - Get progress of a model download

## 5. Games & GeForce Now (GFN) Integration
APIs for Steam library integration, game prices, and GeForce Now optimization.
- [ ] `GET /api/steam-library` - Fetch Steam library
- [ ] `GET /api/game-prices` - Fetch game pricing/deals
- [ ] `GET /api/game-info` - Get specific game info
- [ ] `GET /api/gfn/games` - Fetch supported GFN games
- [ ] `POST /api/gfn/optimize` - Optimize game settings for GFN

## 6. News & RSS Feeds
APIs for fetching generic news, developer news, and deals.
- [ ] `GET /api/news-feed` - Master news feed
- [ ] `GET /api/news` - Generic news
- [ ] `GET /api/deals` - Deal scraping
- [ ] `GET /api/dev-news` - Developer specific news feed

## 7. Settings, Configuration & WebAuthn
Admin endpoints for saving API keys and system settings.
- [ ] `GET /api/settings/voice/get` - Get current TTS voice setting
- [ ] `POST /api/settings/voice` - Update TTS voice setting
- [ ] `POST /api/settings/login_password` - Update login password
- [ ] `POST /api/settings/sudo_password` - Update sudo password
- [ ] `POST /api/admin/save-keys` - Save API keys (Groq, OpenAI, etc.)
- [ ] `GET /webauthn/list` - List registered WebAuthn credentials
- [ ] `POST /webauthn/clear` - Clear WebAuthn credentials

## 8. Google Workspace Integration (`old_swarm_google_api.py`)
This file contains extensive Google API integrations. A decision must be made whether to port these as separate Microservices or integrate them into `LucyServer`.

### Authentication
- [ ] Google Login/Logout (`/login`, `/logout`, `/auth_status`, `/upload_credentials`)

### Gmail API
- [ ] Inbox retrieval & Search (`gmail_inbox`, `gmail_search`, `gmail_unread`)
- [ ] Email actions (`gmail_send`, `gmail_reply`, `gmail_forward`, `gmail_draft`)
- [ ] Email management (`gmail_mark_read`, `gmail_star`, `gmail_trash`, `gmail_archive`)
- [ ] Metadata (`gmail_labels`, `gmail_stats`, `gmail_thread`)

### Google Calendar API
- [ ] Event viewing (`cal_list`, `cal_events`, `cal_events_date`)
- [ ] Event management (`cal_create_event`, `cal_quick`, `cal_update`, `cal_delete`)

### Google Drive API
- [ ] File navigation & Search (`drive_list`, `drive_search`)
- [ ] File management (`drive_folder`, `drive_share`, `drive_delete`)
- [ ] Storage info (`drive_quota`, `drive_stats`)

### Google Tasks API
- [ ] List management (`tasks_lists`, `tasks_create_list`)
- [ ] Task management (`tasks_get`, `tasks_create`, `tasks_complete`, `tasks_update`, `tasks_delete`)

### Google Keep API (Notes & Checklists)
- [ ] Connection management (`keep_connect`, `keep_status`)
- [ ] Notes management (`notes_write`, `notes_read`, `notes_get`, `notes_update`, `notes_erase`, `notes_restore`)
- [ ] Advanced Notes (`notes_checklist`, `notes_labels`)

### Google Contacts API
- [ ] Contacts management (`contacts_list`, `contacts_search`, `contacts_create`)

## 9. Swarm Agents
Ensure any system prompts or custom RAG ingestion jobs not covered by the `SwarmRouterService` are ported. 
- [ ] Port any background indexing jobs for the `rag_store.json`
- [ ] Google Search integration tool (`/api/google/brief`)
