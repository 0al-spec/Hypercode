install:
	npm install

lint:
	@npx biome check --write && \
	npx biome lint --write && \
	npx biome format --write;

type-check:
	@npx tsc -p tsconfig.json

run:
	@npx tsx src/index.ts
