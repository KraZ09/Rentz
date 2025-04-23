extends Node2D

const suites = ["Diamonds", "Hearts", "Clubs", "Spades"]
var deck: Array[Card] = []
var currentTrick: Array[Card] = [] # Cards in the current round
var trickIndex = 0 # Starts at 0, ends at numOfPlayers

var cardAtlas = preload("res://Card/all_cards.png") as Texture2D # Spritesheet

const numOfPlayers = 4
var playerScene = preload("res://Scenes/player.tscn") as PackedScene
var players : Array[Player] = []

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
			playCard(playerId, card) # call the function to play that card
			thisButton.queue_free()
		)

func distributeCards() -> void: # Give each player their cards
	var cardsPerPlayer = 2 * numOfPlayers
	
	for r in range(cardsPerPlayer):
		for i in range(numOfPlayers):
			var card = deck.pop_front() # Take the top card and give it to the player
			card.ownerId = i # Set the card id
			players[i].hand.append(card)

func playCard(playerId: int, card : Card) -> void: # Logic for playing the card
	players[playerId].hand.erase(card) # Remove the card from player's hand
	currentTrick.append(card) # Add played card to trick
	
	# Show the current trick
	var playedCard = Sprite2D.new()
	playedCard.texture = card.image
	playedCard.position += Vector2(trickIndex * 40,0)
	trickArea.add_child(playedCard)
	trickIndex += 1
	
	if trickIndex == numOfPlayers: # Complete trick
		await get_tree().create_timer(1.0).timeout
		trickIndex = 0
		trickEnd()

func trickEnd() -> void:
	# FIND OUT WHO WON
	for child in trickArea.get_children():
		child.queue_free()
		currentTrick.clear()

func _ready() -> void:
	generateCards()
	shuffleDeck()
	instantiatePlayers()
	distributeCards()
	
	displayHand(0)
	displayHand(1)
	displayHand(2)
	displayHand(3)
