package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const (
	targetProductID = "203c5313-5f10-4364-b746-1c8c30892512"
	targetTaxID     = "067d4bf7-fce7-11f1-ed25-1e15c1dbc133"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/rule", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s", r.Method, r.URL.Path)
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "failed to read body", http.StatusBadRequest)
			return
		}

		var req RuleRequest
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}

		response := RuleResponse{Actions: []Action{}}
		if !containsProduct(req.Sale.LineItems, targetProductID) {
			response.Actions = []Action{
				AddLineItemAction{
					ProductID: targetProductID,
					Quantity:  "1",
					UnitPrice: "3.75",
					TaxID:     targetTaxID,
				},
			}
		} else {
			log.Printf("product %s already in sale, returning empty actions", targetProductID)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	})

	srv := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	// Run the server in a goroutine so main can wait for a shutdown signal.
	serverErr := make(chan error, 1)
	go func() {
		log.Println("server listening on :8080")
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	// Wait for either a fatal server error or a termination signal (SIGINT
	// from Ctrl+C, SIGTERM from `kill`/`make` cleanup).
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	select {
	case err := <-serverErr:
		log.Fatalf("server error: %v", err)
	case sig := <-stop:
		log.Printf("received %s, shutting down...", sig)
	}

	// Give in-flight requests up to 10s to finish, then force close.
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed, forcing close: %v", err)
		srv.Close()
	}
	log.Println("server stopped")
}

func containsProduct(items []LineItem, productID string) bool {
	for _, item := range items {
		if item.ProductID == productID {
			return true
		}
	}
	return false
}
