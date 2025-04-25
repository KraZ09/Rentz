extends Node2D

const suites = ["Diamonds", "Hearts", "Clubs", "Spades"]
var deck: Array[Card] = []
var currentTrick: Array[Card] = [] # Cards in the current round
var trickIndex = 0 # Starts at 0, ends at numOfPlayers
var cardsPerPlayer = 2 * numOfPlayers # How many cards does each player have
signal cardPlayed(player_id: int)
var leadSuit # Which suit wins the trick
var canPlay := true # Can the players play a card

var gameModes = ["pig"] # List of playable gameModes
var currentGameMode : String

var cardAtlas = preload("res://Sprites/all_cards.png") as Texture2D # Spritesheet

const numOfPlayers = 4
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
		ace.value = 15
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
	if not canPlay:
		print("Wait for the trick to clear!")
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
			print("You must follow suit!")
			return false
		
		# Everything is fine
		return true

func displayHand(playerId: int) -> void: # Show the player's hand
	for i in range(players[playerId].hand.size()):
		# For convenience these are buttons
		# They are only created on this function which is called only for the user
		var card = players[playerId].hand[i]
		
		var button = TextureButton.new()
		button.texture_normal = card.image
		button.position = Vector2(cardWidth * i - 900, playerId * 150 - 70)
		add_child(button)
		
		var thisButton = button
		
		button.pressed.connect(func():
			print("Player %d played: %s of %d" % [playerId, card.suit, card.value])
			# Check if it is the player's turn
			if isValid(card, playerId):
				playCard(playerId, card) # call the function to play that card
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
	
	emit_signal("cardPlayed", playerId)

func RoundStart(gameMode : String) -> void: # Minigame loop
	shuffleDeck() # Shuffle the deck and give every player their cards
	distributeCards()
	
	var totalCardsPlayed = 0 # How many cards have been played the whole round
	while (totalCardsPlayed < (cardsPerPlayer * numOfPlayers)):
		for j in range(numOfPlayers):
			currentPlayerIndex = (startingPlayerId + j) % numOfPlayers 
			# Make it so it loops thorugh all players, starting at the last Winner
			
			await cardPlayed
			totalCardsPlayed += 1
			trickIndex += 1
			
			if trickIndex == numOfPlayers: # Complete trick
				canPlay = false
				await get_tree().create_timer(1.0).timeout
				trickEnd()
				canPlay = true
	print("Round over!")
	calculateScore(gameMode) # Calculate the scores
	displayScores() # Show all of the scores

func trickEnd() -> void: # Determine the winner
	# The first card determines what theo others play
	var highestValue = -1
	var winnerId = -1
	
	for card in currentTrick:
		if card.suit == leadSuit and card.value > highestValue:
			highestValue = card.value
			winnerId = card.ownerId
	
	print("Player %d won the trick with %s of %d" % [winnerId, leadSuit, highestValue])
	startingPlayerId = winnerId # For the next round, the winner is going to pick a suit
	
	# Remove visuals
	for child in trickArea.get_children():
		child.queue_free()
	
	trickIndex = 0
	currentTrick.clear() # Clear array

func displayScores() -> void: # Display all scores
	for p in players:
		print("Player %d scored %d points" % [p.id, p.score])

# Calculate the scores based on gamemode
func calculateScore(gameMode : String) -> void:  
	var rScore = 0 # Score of the current round
	match gameMode:
		# For the pig variant, the player who wins the K of Hearts loses 200 points
		"pig": 
			for player in players: # Loop through the hands of all players
				for card in player.wonCards:
					if card.value == 14 and card.suit == "Hearts":
						player.score -= 200 # - 200 points
						return # There is only one pig in the game so no need to search further
		# Other gamemodes

func _ready() -> void:
	generateCards()
	instantiatePlayers()
	currentGameMode = "pig"
	RoundStart(currentGameMode)
	
	displayHand(0)
	displayHand(1)
	displayHand(2)
	displayHand(3)
