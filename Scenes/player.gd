extends Node

class_name Player

var id : int
var hand: Array[Card] # Current cards in player's hand
var wonCards: Array[Card] # Cards that the player has won
var isHuman: bool = true # True for now for debugging
var score: int

func playCard(card : Card) -> void:
	if hand.has(card):
		hand.erase(card)
	else:
		push_error("card is not in hand!")
