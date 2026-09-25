# NVIDIA Runtime Policy for SWARM OS

SWARM OS uses NVIDIA capabilities as remote HTTP services. The current target
machine has 16 GB of system RAM and Intel UHD integrated graphics. It has no
NVIDIA GPU, so local NVIDIA NIM containers are not a supported deployment mode
for this machine.

## Current execution paths

| Caller | Endpoint owner | Credential | Local GPU required |
|---|---|---|---|
| `LucyServer-go/services/llm.go` for `nvidia/*` models | NVIDIA hosted API at `integrate.api.nvidia.com` | `NVIDIA_API_KEY` | No |
| Flutter `SkillRouter` and its NVIDIA facades | OpenRouter API | `OPENROUTER_API_KEY` | No |
| GamingAgent Lucille chat/eval | OpenRouter API | `OPENROUTER_API_KEY` | No |
| Vosk wake-word listener | Local CPU | None | No |

The client needs network access, its provider credential at runtime, and enough
ordinary RAM for the OS and application. CUDA, cuDNN, TensorRT, NVIDIA drivers,
and NVIDIA Container Toolkit are not required for these hosted calls.

Credentials are supplied at runtime through SWARM's sealed environment flow.
Do not put API keys in this document, source files, package lists, or an ISO.

## Current hardware decision

Keep NVIDIA features cloud-first on the present 16 GB Intel UHD machine.
Do not add `nvidia-container-toolkit`, CUDA, cuDNN, TensorRT, NVIDIA drivers, or
local NIM images to `packages.x86_64`. Those packages would increase the ISO
and do not make an Intel integrated GPU capable of running NVIDIA GPU
containers.

Lightweight local work remains appropriate on this machine: wake-word
detection, basic speech capture, SQLite/vector storage, request preparation,
and small CPU-only fallback models after measurement. Large language,
multimodal, image-generation, and NVIDIA-specific inference should remain on a
hosted provider or a separate supported NVIDIA system.

## Requirements for a future local NIM host

Treat local NIM as a separate host profile, not as a package toggle on every
SWARM ISO. Before enabling it, verify all of the following against the selected
NIM's current support matrix:

1. A supported NVIDIA GPU with enough dedicated VRAM for that exact model and
   profile. Shared Intel graphics memory does not qualify.
2. A supported NVIDIA driver, CUDA stack, container engine, and NVIDIA
   Container Toolkit.
3. Enough system RAM and storage for the container and model cache.
4. A supported operating system. NVIDIA recommends Ubuntu for NIM LLM/VLM
   deployments; Arch-based SWARM OS is not listed as a validated NIM platform.
5. A successful isolated runtime check before any service is enabled at boot.

NVIDIA's documentation gives model-specific memory requirements; there is no
single safe minimum for all NIMs. For example, NVIDIA's current prerequisites
page lists 24 GB of GPU memory for one 8B LLM profile. Always use the selected
model's support matrix instead of estimating from parameter count.

## Future integration boundary

If a supported NVIDIA workstation or server is added later, run NIM there and
expose only its authenticated API over the trusted network or Tailscale. Keep
the SWARM OS client path provider-neutral so the 16 GB laptop remains a thin
client and can fall back to a hosted endpoint when that NIM host is offline.

Do not add NVIDIA packages to the base ISO until a real NVIDIA host exists and
the exact NIM passes container startup, health, inference, restart, and memory
pressure tests on that host.

## Authoritative references

- NVIDIA NIM LLM/VLM prerequisites:
  https://docs.nvidia.com/nim/large-language-models/latest/get-started/prerequisites.html
- NVIDIA Container Toolkit installation:
  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
- NVIDIA Container Toolkit platform support:
  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/supported-platforms.html

