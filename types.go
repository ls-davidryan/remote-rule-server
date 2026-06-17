package main

import "encoding/json"

type RuleRequest struct {
	Sale Sale `json:"sale"`
}

type Sale struct {
	LineItems []LineItem `json:"line_items"`
}

type LineItem struct {
	ProductID string `json:"product_id"`
}

type Action interface {
	actionType() string
}

type AddLineItemAction struct {
	ProductID string `json:"product_id"`
	Quantity  string `json:"quantity"`
	UnitPrice string `json:"unit_price"`
	Note      string `json:"note"`
	TaxID     string `json:"tax_id"`
}

func (a AddLineItemAction) actionType() string { return "add_line_item" }

func (a AddLineItemAction) MarshalJSON() ([]byte, error) {
	type Alias AddLineItemAction
	return json.Marshal(struct {
		Type string `json:"type"`
		Alias
	}{
		Type:  a.actionType(),
		Alias: Alias(a),
	})
}

type RuleResponse struct {
	Actions []Action `json:"actions"`
}
