FROM julia:1.10-bullseye

WORKDIR /usr/src/app
COPY . .

RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'
ENV JULIA_PROJECT=/usr/src/app