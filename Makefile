.PHONY: run tunnel install-lt start

-include .env
export

PORT := 8080

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
	lt --port $(PORT) --subdomain $(SUBDOMAIN)

start: install-lt
	@if [ -z "$(SUBDOMAIN)" ]; then \
		echo "Error: SUBDOMAIN is not set in .env"; exit 1; \
	fi
	go run . & lt --port $(PORT) --subdomain $(SUBDOMAIN)
