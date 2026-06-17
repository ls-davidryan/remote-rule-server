package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
)

const (
	targetProductID = "203c5313-5f10-4364-b746-1c8c30892512"
	targetTaxID     = "067d4bf7-fce7-11f1-ed25-1e15c1dbc133"
)

func main() {
	http.HandleFunc("/rule", func(w http.ResponseWriter, r *http.Request) {
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

	log.Println("server listening on :8080")
	http.ListenAndServe(":8080", nil)
}

func containsProduct(items []LineItem, productID string) bool {
	for _, item := range items {
		if item.ProductID == productID {
			return true
		}
	}
	return false
}
