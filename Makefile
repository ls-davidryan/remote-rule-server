.PHONY: run tunnel install-lt start kill

-include .env
export

PORT := 8080

# Use bash so the tunnel verification script below behaves consistently.
SHELL := /bin/bash

run:
	go run .

# Kill any process currently listening on $(PORT).
kill:
	@pids=$$(lsof -ti tcp:$(PORT) 2>/dev/null); \
	if [ -n "$$pids" ]; then \
		echo "Killing process(es) on port $(PORT): $$pids"; \
		kill $$pids 2>/dev/null || true; \
	else \
		echo "No process running on port $(PORT)"; \
	fi

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

start: kill install-lt
	@if [ -z "$(SUBDOMAIN)" ]; then \
		echo "Error: SUBDOMAIN is not set in .env"; exit 1; \
	fi
	@go build
	@go run . & \
	server_pid=$$!; \
	$(start_tunnel)

# Start lt and verify it actually granted the requested subdomain.
# localtunnel silently falls back to a random subdomain when the requested
# one is taken, so we watch its output and fail instead of running on the
# wrong URL.
#
# lt runs in the background (writing to a FIFO) so we keep its PID. localtunnel
# has no "release subdomain" call: the server frees the subdomain once lt's
# sockets close, so the only thing we must guarantee is that lt is actually
# terminated. cleanup() sends SIGTERM to lt (and the server) so Node closes its
# sockets gracefully, and it runs on Ctrl+C (INT), TERM/HUP, the
# wrong-subdomain failure, and normal exit. We wait in a loop instead of a bare
# `wait` so an incoming signal interrupts the wait and the trap fires promptly.
define start_tunnel
	expected="https://$(SUBDOMAIN).loca.lt"; \
	fifo=$$(mktemp -u); mkfifo "$$fifo"; \
	lt --port $(PORT) --subdomain $(SUBDOMAIN) > "$$fifo" 2>&1 & \
	lt_pid=$$!; \
	cleaned=0; \
	cleanup() { \
		[ "$$cleaned" = 1 ] && return; cleaned=1; \
		kill -TERM $$lt_pid $$server_pid 2>/dev/null; \
		wait $$lt_pid $$server_pid 2>/dev/null; \
		rm -f "$$fifo"; \
	}; \
	trap 'cleanup; exit 130' INT; \
	trap 'cleanup; exit 143' TERM HUP; \
	trap 'cleanup' EXIT; \
	status=0; \
	while IFS= read -r line; do \
		echo "$$line"; \
		if [[ "$$line" == *"your url is:"* ]]; then \
			url=$$(echo "$${line##*your url is: }" | tr -d '[:space:]'); \
			if [[ "$$url" != "$$expected" ]]; then \
				echo "Error: requested subdomain '$(SUBDOMAIN)' was unavailable; localtunnel assigned $$url instead." >&2; \
				status=1; break; \
			fi; \
		fi; \
	done < "$$fifo"; \
	if [[ $$status -ne 0 ]]; then exit $$status; fi; \
	while kill -0 $$lt_pid 2>/dev/null; do wait $$lt_pid; done
endef
