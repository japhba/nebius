### Environment
You are running on a cpu-only dev node on Nebius. Our typical setup will be to rent out gpus on demand which will have the codebase already, and orchestrate runs on there.

### Coding Style & Execution
- **Fail Fast:** Do not include defensive guards (e.g., `try: except`, `dictionary.get()`, `if len(data) == 0`) when in doubt. Code should fail loudly rather than silently to avoid bloated code and silent failures.
- **Modernity over Compatibility:** Do not worry about backward compatibility.
- **Boilerplate:** Keep boilerplate code on a single line where possible rather than line-breaking.
- **Progress Tracking:** Liberally use `tqdm.auto`; 2-3 nested levels are acceptable.

### Environment & Storage
- **Virtual Environments:** Always create environments using `UV_PROJECT_ENVIRONMENT="$VENV_LOCAL/${PWD##*/}" uv sync` (where `VENV_LOCAL` is defined in `~/.bashrc`).
- **NFS Awareness:** Never build virtual environments in the project directory, as it uses slow NFS storage.
- **Data Caching:** Respect environment variables from `~/.env` via `python-dotenv`. Never save large files/models to `~/`; always use the specified cache directory.

### Data Logging, HF & Version Control
- **Hugging Face:** Always push datasets using the `PARQUET` format.
- **Version Control:** Do not push work automatically.
- **SLURM Tracking:** Never commit SLURM scripts to version control.
