.PHONY: run tunnel install-lt start

-include .env
export

PORT := 8080

# Use bash so the tunnel verification script below behaves consistently.
SHELL := /bin/bash

run:
	go run .

install-lt:
	@if ! command -v lt > /dev/null 2>&1; then \
		echo "Installing localtunnel..."; \
		npm install -g localtunnel; \
	else \
		echo "localtunnel already installed"; \
	fi

tunnel: install-lt
	@if [ -z "$(SUBDOMAIN)" ]; then \
		echo "Error: SUBDOMAIN is not set in .env"; exit 1; \
	fi
	@$(start_tunnel)

start: install-lt
	@if [ -z "$(SUBDOMAIN)" ]; then \
		echo "Error: SUBDOMAIN is not set in .env"; exit 1; \
	fi
	@go build
	@go run . & \
	server_pid=$$!; \
	trap 'kill $$server_pid 2>/dev/null' EXIT INT TERM; \
	$(start_tunnel)

# Start lt and verify it actually granted the requested subdomain.
# localtunnel silently falls back to a random subdomain when the requested
# one is taken, so we watch its output and fail instead of running on the
# wrong URL.
define start_tunnel
	expected="https://$(SUBDOMAIN).loca.lt"; \
	exec lt --port $(PORT) --subdomain $(SUBDOMAIN) 2>&1 | { \
		lt_pgid=$$$$; \
		while IFS= read -r line; do \
			echo "$$line"; \
			if [[ "$$line" == *"your url is:"* ]]; then \
				url=$$(echo "$${line##*your url is: }" | tr -d '[:space:]'); \
				if [[ "$$url" != "$$expected" ]]; then \
					echo "Error: requested subdomain '$(SUBDOMAIN)' was unavailable; localtunnel assigned $$url instead." >&2; \
					exit 1; \
				fi; \
			fi; \
		done; \
	}
endef
