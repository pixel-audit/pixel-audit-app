# PixelAudit — the local development stack.
#
#   make setup   first time: Docker services, the API's dependencies and
#                database (migrated, CONNECTION_* applied), the panel's npm
#   make up      everything: Docker services, then the API and the panel
#                from the Procfile via foreman (API on 16000, panel on 16001)
#   make boot    re-run the API's boot role — after editing .env
#   make check   what CI runs: the API's precommit, the panel's checks,
#                the Helm chart's lint

setup: docker-up postgres-wait api-setup admin-setup

api-setup:
	cd ./src/api && mix deps.get && mix boot

admin-setup:
	cd ./src/admin && npm install

# The API's boot role in development: create, migrate, map the CONNECTION_*
# environment (.env, loaded by foreman — or exported in the shell) onto
# connection rows.
boot:
	cd ./src/api && mix boot

# Regenerates the panel's typed API client (orval) from the OpenAPI document
# served by the Phoenix API. An already-running API (make up, or
# `mix phx.server` in src/api) is used as-is; otherwise one is started just
# for the generation and stopped afterwards.
openapi-generate:
	@if curl -fso /dev/null http://localhost:16000/openapi/admin.json; then \
	    $(MAKE) admin-openapi-generate; \
	else \
	    echo "API is not running — starting it for the generation (log: /tmp/pixelaudit-openapi-api.log)..."; \
	    ( cd ./src/api && PORT=16000 mix phx.server > /tmp/pixelaudit-openapi-api.log 2>&1 & \
	      echo $$! > /tmp/pixelaudit-openapi-api.pid ); \
	    apipid=$$(cat /tmp/pixelaudit-openapi-api.pid); rm -f /tmp/pixelaudit-openapi-api.pid; \
	    tries=0; \
	    until curl -fso /dev/null http://localhost:16000/openapi/admin.json; do \
	        tries=$$((tries+1)); \
	        if [ $$tries -ge 120 ] || ! kill -0 $$apipid 2>/dev/null; then \
	            echo "The API did not come up — see /tmp/pixelaudit-openapi-api.log"; \
	            kill $$apipid 2>/dev/null; \
	            exit 1; \
	        fi; \
	        echo "Waiting for the API..."; \
	        sleep 1; \
	    done; \
	    $(MAKE) admin-openapi-generate; status=$$?; \
	    kill $$apipid; \
	    exit $$status; \
	fi

admin-openapi-generate:
	cd ./src/admin && npm run api:generate && npm run typecheck

postgres-wait:
	@until docker compose exec postgres pg_isready -U postgres -q; do \
	    echo "Waiting for postgres..."; \
	    sleep 1; \
	done

up: docker-up orphans-kill deps-check app-up

deps-check:
	@if [ ! -d ./src/admin/node_modules ]; then \
	    echo "./src/admin/node_modules is missing — run 'make setup' first"; \
	    exit 1; \
	fi

docker-up:
	docker compose up -d

app-up:
	foreman start

# The sample databases a postgres_query and a clickhouse_query data source
# can be pointed at (docker-compose.yml, profile `targets`; the matching
# CONNECTION_* lines are in .env.example).
targets-up:
	docker compose --profile targets up -d

targets-down:
	docker compose --profile targets down

down: docker-down

docker-down:
	docker compose --profile targets down

clean: docker-clean api-clean admin-clean

docker-clean:
	docker compose --profile targets down --volumes --remove-orphans

api-clean:
	rm -rf ./src/api/_build ./src/api/deps

admin-clean:
	rm -rf ./src/admin/node_modules ./src/admin/dist

orphans-kill:
	@for port in 16000 16001; do \
	    pid=$$(lsof -ti tcp:$$port 2>/dev/null); \
	    if [ -n "$$pid" ]; then \
	        echo "Killing process on port $$port (PID: $$pid)"; \
	        kill -9 $$pid; \
	    else \
	        echo "No process found on port $$port"; \
	    fi \
	done

check: api-check admin-check helm-lint

api-check:
	cd ./src/api && mix precommit

admin-check:
	cd ./src/admin && npm run check

# The Helm chart (deploy/): lint, and a render of the two example values
# files checked against the Kubernetes schemas when kubeconform is installed.
helm-lint:
	helm lint ./deploy --values ./deploy/examples/values-minimal.yaml
	helm lint ./deploy --values ./deploy/examples/values-all-in-one.yaml
	@if command -v kubeconform >/dev/null 2>&1; then \
	    helm template pixelaudit ./deploy --values ./deploy/examples/values-minimal.yaml | kubeconform -strict -ignore-missing-schemas; \
	else \
	    echo "kubeconform not installed — skipping the schema check"; \
	fi

# The two images, built locally the way CI builds them.
images:
	docker build -t pixelaudit-api ./src/api
	docker build -t pixelaudit-admin ./src/admin
