# syntax=docker/dockerfile:1
ARG JULIA_IMAGE=julia:1.11.9-bookworm
FROM ${JULIA_IMAGE}

ENV JULIA_DEPOT_PATH=/opt/julia-depot \
    JULIA_PROJECT=/opt/gems-env \
    JULIA_CPU_TARGET=generic \
    JULIA_NUM_THREADS=2 \
    JULIA_NUM_PRECOMPILE_TASKS=2 \
    OPENBLAS_NUM_THREADS=1 \
    GKSwstype=100 \
    QT_QPA_PLATFORM=offscreen

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates git libgl1 libglib2.0-0 libxrender1 libxext6 libxt6 \
       fontconfig fonts-dejavu-core ghostscript pandoc libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

# "gems" is a read-only build context supplied by Compose. The host repo is never mounted at runtime.
COPY --from=gems /Project.toml /opt/GEMS/Project.toml
COPY --from=gems /src /opt/GEMS/src
COPY --from=gems /data /opt/GEMS/data
COPY --from=gems /docs/src/glossary.md /opt/GEMS/docs/src/glossary.md
COPY --from=gems /LICENSE /opt/GEMS/LICENSE
COPY --from=gems /README.md /opt/GEMS/README.md

# Keep the resolved Manifest outside the package. Resolution happens only during image build.
# Cache dependency installation separately so an import/precompile failure does not discard it.
RUN mkdir -p /opt/gems-env /opt/GEMS/localdata /opt/GEMS/temp /input /output /work \
    && JULIA_PKG_PRECOMPILE_AUTO=0 julia --startup-file=no --project=/opt/gems-env -e \
       'using Pkg; Pkg.develop(path="/opt/GEMS"); Pkg.instantiate()'
RUN julia --startup-file=no --project=/opt/gems-env -e \
    'using Pkg; Pkg.precompile(); using GEMS'
RUN find /opt/GEMS -type f -print0 | sort -z | xargs -0 sha256sum > /opt/gems-env/source.sha256

COPY run.jl /opt/runner/run.jl
WORKDIR /work
ENV HOME=/work \
    JULIA_DEPOT_PATH=/work/julia:/opt/julia-depot \
    JULIA_NUM_THREADS=8
ENTRYPOINT ["julia", "--startup-file=no", "--project=/opt/gems-env", "/opt/runner/run.jl"]
