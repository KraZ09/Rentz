extends Node2D

@onready var main: Node2D = $"."

const suites = ["Diamonds", "Hearts", "Clubs", "Spades"]
var deck: Array[Card] = []

var numOfPlayers = 4
var currentTrick: Array[Card] = [] # Cards in the current round
var trickIndex = 0 # Starts at 0, ends at cardsPerPlayer
var cardsPerPlayer = 2 * numOfPlayers # How many cards does each player have
signal cardPlayed(player_id: int)
var leadSuit # Which suit wins the trick
var canPlay := true # Can the players play a card
# If the objective of the game has been reached but player's haven't finished their cards...
# the round will end early (Ex: Pig was won in first trick)
var roundShouldEnd := false

var gameModes = ["pig", "diamonds", "queens", "totalPlus", "totalMinus"] 
# List of playable gameModes
var currentGameMode : String

var cardAtlas = preload("res://Sprites/all_cards.png") as Texture2D # Spritesheet

var playerScene = preload("res://Scenes/player.tscn") as PackedScene
var players : Array[Player] = []
var currentPlayerIndex  = 0 # Id for the player that has to play
var startingPlayerId : int = 0 # Id of the player that starts the trick

@onready var trickArea: Node2D = $TrickArea

# Card dimensions from the sheet
const cardWidth = 101
const cardHeight = 141
const horizontalGap = 21
const verticalGap = 28

func generateCards() -> void: # Generate the DECK
	for s in range(suites.size()): # 4 types of cards
		var suit =  suites[s]
		for v in range(7, 14): # Start at 7, end at K (for 4 players)
			var newCard = Card.new()
			newCard.suit = suit
			newCard.value = v
			newCard.image = createCardTexture(s, v - 1)
			deck.append(newCard) # Actually put it in the deck
			# Ignore the owner id for now
		
		# Because I am too lazy and the spritesheet starts at Ace,
		# I am going to add them later and alter their value to 15
		
		var ace = Card.new()
		ace.suit = suit
		ace.value = 14 # K is 13
		ace.image = createCardTexture(s, 0) # Ace is at index 0 in sheet
		deck.append(ace)

# Assign the textures correctly, with the gaps between the sprites
func createCardTexture(suitIndex: int, valueIndex: int) -> AtlasTexture:
	var texture = AtlasTexture.new()
	texture.atlas = cardAtlas
	var x = valueIndex * (cardWidth + horizontalGap) # gaps resolved
	var y = suitIndex * (cardHeight + verticalGap)
	texture.region = Rect2(x, y, cardWidth, cardHeight)
	return texture
# Guess what this does
func shuffleDeck() -> void:
	deck.shuffle()

func instantiatePlayers() -> void: # Make the players actually exist
	for x in range(numOfPlayers):
		var p = playerScene.instantiate() as Player
		p.id = x
		add_child(p)
		players.append(p)

func isValid(card: Card, playerId: int) -> bool: # Validate moves
	if not canPlay: # Make the players unable to play while any type of loading
		print("Can't play now!")
		return false
	
	if (currentPlayerIndex != playerId): # Check if it is the player's turn
		print("Not your turn!")
		return false
	else:
		var hasLeadSuit : bool = false
		# Check if the player has the suit, if not let them play anything
		
		if (currentTrick.size() == 0): # If it is the first round, don't check
			return true
		else : # If the leadSuit has been chosen
			for c in players[playerId].hand: # Check every card in his hand for the leadSuit
				if (c.suit == leadSuit):
					hasLeadSuit = true
					break
		if hasLeadSuit and (card.suit != leadSuit): # Make the player follow the suit
			print("You must follow the suit!")
			return false
		
		# Everything is fine
		return true

func displayHand(playerId: int) -> void: # Show the player's hand
	for i in range(players[playerId].hand.size()):
		# For convenience these are buttons
		# They are only created on this function which is called only for the user
		var card = players[playerId].hand[i]
		
		var button = TextureButton.new() # Create and move the button
		button.texture_normal = card.image
		button.position = Vector2(cardWidth * i - 900, playerId * 150 - 70)
		add_child(button)
		
		var thisButton = button
		
		button.pressed.connect(func():
			# Check if it is the player's turn
			if isValid(card, playerId):
				playCard(playerId, card) # Call the function to play the clicked card
				thisButton.queue_free() # Delete the button
		)

func distributeCards() -> void: # Give each player their cards
	for r in range(cardsPerPlayer):
		for i in range(numOfPlayers):
			var card = deck.pop_front() # Take the top card and give it to the player
			card.ownerId = i # Set the card id
			players[i].hand.append(card)

func playCard(playerId: int, card : Card) -> void: # Logic for playing the card
	# If the move is legal, proceed
	players[playerId].hand.erase(card) # Remove the card from player's hand
	currentTrick.append(card) # Add played card to trick
	
	if (currentTrick.size() == 1): # Set the lead if it is the first card
		leadSuit = currentTrick[0].suit
	
	# Show the current trick
	var playedCard = Sprite2D.new()
	playedCard.texture = card.image
	playedCard.position += Vector2(trickIndex * 40,0)
	trickArea.add_child(playedCard)
	
	print("Player %d played: %d of %s" % [playerId, card.value, card.suit])
	
	emit_signal("cardPlayed", playerId)

func RoundStart(gameMode : String) -> void: # Minigame loop
	shuffleDeck() # Shuffle the deck and give every player their cards
	distributeCards()
	
	var totalCardsPlayed = 0 # How many cards have been played the whole round
	while (totalCardsPlayed < (cardsPerPlayer * numOfPlayers) and !roundShouldEnd):
		for j in range(numOfPlayers):
			currentPlayerIndex = (startingPlayerId + j) % numOfPlayers 
			# Make it so it loops thorugh all players, starting at the last Winner
			
			# Wait for player to play a card
			await cardPlayed
			totalCardsPlayed += 1
			trickIndex += 1
			
			# Complete trick if every player has put down a card
			if trickIndex == numOfPlayers:
				canPlay = false
				await get_tree().create_timer(1.0).timeout
				trickEnd()
				canPlay = true
				# After completing the trick, check for remaining objectives
				earlyEndCheck(gameMode)
			
			if roundShouldEnd:
				print("No objectives left! Round ended early")
				break # Stop the round
	
	print("Round over!")
	calculateScore(gameMode) # Calculate the scores
	displayScores() # Show all of the scores
	roundEnd() # Delete unecessary data

func roundEnd() -> void: # Delete all data except score
	for p in players:
		p.wonCards.clear()
		p.hand.clear()
	# Also delete card buttons
	for child in main.get_children():
		if child is TextureButton:
			child.queue_free()

func trickEnd() -> void: # Determine the winner of the currentTrick
	# The first card determines what the others must play
	var highestValue = -1
	var winnerId = -1
	
	for card in currentTrick: # Find out who won the trick
		if card.suit == leadSuit and card.value > highestValue:
			highestValue = card.value
			winnerId = card.ownerId
	
	print("Player %d won the trick with %d of %s" % [winnerId, highestValue, leadSuit])
	startingPlayerId = winnerId # For the next round, the winner is going to pick the leadSuit
	
	# Give all of the cards in the trick to the winning player
	for k in currentTrick: # Loop through all 4 cards
		k.ownerId = winnerId # Set the id
		players[winnerId].wonCards.append(k) # Add it to wonCards array
	
	# Remove visuals
	for child in trickArea.get_children():
		child.queue_free()
	
	trickIndex = 0
	currentTrick.clear() # Clear array

func displayScores() -> void: # Display all scores
	for p in players:
		print("Player %d scored %d points" % [p.id, p.score])

func earlyEndCheck(gameMode : String) -> void: # Avoid tricks that do not affect score
	roundShouldEnd = false # Reset earlyEnd bool
	match gameMode:
		"pig": # If the pig is no longer in the game, end the round eary
			for player in players:
				for c in player.wonCards:
					if c.value == 13 and c.suit == "Hearts":
						roundShouldEnd = true # Pig was found, end round
						return
		"diamonds":
			# In this case, it is faster to start assuming there are no diamonds
			# and check for them in the player's hands
			roundShouldEnd = true
			for player in players:
				for card in player.hand:
					if card.suit == "Diamonds":
						roundShouldEnd = false # There are still diamonds in the game
						return
		"queens":
			roundShouldEnd = true # Check for queens still in game
			for player in players:
				for card in player.hand:
					if card.value == 12:
						roundShouldEnd = false
						return
# Calculate the scores based on gamemode
func calculateScore(gameMode : String) -> void:
	match gameMode:
		# For the pig variant, the player who wins the K of Hearts loses 200 points
		"pig": 
			for player in players: # Loop through the hands of all players
				for card in player.wonCards:
					if card.value == 13 and card.suit == "Hearts":
						player.score -= 200 # - 200 points
						return # There is only one pig in the game so no need to search further
		"diamonds": # Each card of diamonds is -25 points
			for player in players:
				for card in player.wonCards:
					if card.suit == "Diamonds":
						player.score -= 25;
		"queens": # Each queen is -50 points
			for player in players:
				for card in player.wonCards:
					if card.value == 12:
						player.score -= 50
		"totalPlus":
			# Each trick is +25 and Queens/Diamonds/Pig add instead of subtract
			for player in players:
				for card in player.wonCards:
					# Every won trick is 25
					player.score += (player.wonCards.size() / numOfPlayers) * 25
					
					if card.suit == "Diamonds": # D is 20
						player.score += 25;
					if card.value == 12: # Q is 50
						player.score += 50
					if card.suit == "Hearts" and card.value == 13: # Pig is 200
						player.score += 200
		"totalMinus":
			# Each trick is -25 and Queens/Diamonds/Pig subtract
			for player in players:
				for card in player.wonCards:
					# Every won trick is 25
					player.score -= (player.wonCards.size() / numOfPlayers ) * 25
					
					if card.suit == "Diamonds": # D is 20
						player.score -= 25;
					if card.value == 12: # Q is 50
						player.score -= 50
					if card.suit == "Hearts" and card.value == 13: # Pig is 200
						player.score -= 200
func _ready() -> void:
	generateCards()
	instantiatePlayers()
	currentGameMode = "totalPlus"
	RoundStart(currentGameMode)
	
	displayHand(0)
	displayHand(1)
	displayHand(2)
	displayHand(3)
